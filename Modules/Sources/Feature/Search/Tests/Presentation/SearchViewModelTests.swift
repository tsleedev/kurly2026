import XCTest
import SearchInterface
import SearchTesting
@testable import Search

@MainActor
final class SearchViewModelTests: XCTestCase {

    // MARK: - Factory tracking

    /// `makeSearchResultViewModel` factory가 호출될 때마다 만들어진 VM과 전달된 destination을 누적.
    /// 테스트는 이 배열을 보고 (1) state가 `.results`로 전환됐는지 (2) destination에 trim된 query가
    /// 정확히 전달됐는지 검증한다.
    private var producedResultViewModels: [SearchResultViewModel] = []
    private var capturedDestinations: [SearchResultDestination] = []

    override func setUp() async throws {
        try await super.setUp()
        producedResultViewModels = []
        capturedDestinations = []
    }

    // MARK: - onAppear

    func test_onAppear_state는_recent로_채워진다() async {
        let mock = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let sut = makeSUT(recent: mock)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .recent([Self.keyword("swift", at: 1)]))
    }

    /// SwiftUI `.task`가 WebView push/pop 이후 재발화해도 .results state를 .recent로
    /// 덮어쓰지 않아야 함을 검증.
    func test_onAppear_두번째_호출은_이미_results_상태를_보존한다() async {
        let mock = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let sut = makeSUT(recent: mock)
        await sut.onAppear()
        sut.query = "swift"
        await sut.onSubmit()
        guard case .results = sut.state else {
            XCTFail("선결 조건: onSubmit 후 state == .results")
            return
        }
        await sut.waitForPendingRefresh()

        await sut.onAppear()

        if case .recent = sut.state {
            XCTFail("두 번째 onAppear가 .results를 덮어썼음")
        }
    }

    // MARK: - onSubmit

    func test_onSubmit_query가_비어있으면_save도_state_전환도_없다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)
        sut.query = ""

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, [])
        XCTAssertEqual(capturedDestinations, [])
        XCTAssertEqual(sut.state, .recent([]))
    }

    func test_onSubmit_query가_공백뿐이면_save도_state_전환도_없다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)
        sut.query = "   "

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, [])
        XCTAssertEqual(capturedDestinations, [])
        XCTAssertEqual(sut.state, .recent([]))
    }

    func test_onSubmit_query를_trim해서_save하고_state가_results로_전환된다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)
        sut.query = "  swift  "

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, ["swift"])
        XCTAssertEqual(capturedDestinations, [SearchResultDestination(query: "swift")])
        XCTAssertEqual(sut.query, "swift")
        XCTAssertEqual(producedResultViewModels.count, 1)
        XCTAssertEqual(sut.state, .results(producedResultViewModels[0]))
    }

    // MARK: - onTapRecent

    func test_onTapRecent_query_갱신하고_save하고_state가_results로_전환된다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)

        await sut.onTapRecent("kotlin")

        XCTAssertEqual(sut.query, "kotlin")
        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, ["kotlin"])
        XCTAssertEqual(capturedDestinations, [SearchResultDestination(query: "kotlin")])
        XCTAssertEqual(producedResultViewModels.count, 1)
        XCTAssertEqual(sut.state, .results(producedResultViewModels[0]))
    }

    // MARK: - onConfirmDelete

    func test_onConfirmDelete_지정한_keyword를_삭제하고_state를_갱신한다() async {
        let mock = MockRecentKeywordUseCase(stubRecent: [
            Self.keyword("swift", at: 1),
            Self.keyword("kotlin", at: 2),
        ])
        let sut = makeSUT(recent: mock)
        await sut.onAppear()

        await mock.setStubRecent([Self.keyword("kotlin", at: 2)])
        await sut.onConfirmDelete("swift")

        let deletes = await mock.capturedDeletes
        XCTAssertEqual(deletes, ["swift"])
        XCTAssertEqual(sut.state, .recent([Self.keyword("kotlin", at: 2)]))
    }

    // MARK: - onConfirmDeleteAll

    func test_onConfirmDeleteAll_deleteAll_호출_state가_recent_빈배열로() async {
        let mock = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let sut = makeSUT(recent: mock)
        await sut.onAppear()

        await sut.onConfirmDeleteAll()

        let count = await mock.deleteAllCallCount
        XCTAssertEqual(count, 1)
        XCTAssertEqual(sut.state, .recent([]))
    }

    // MARK: - onQueryChanged (debounce)

    func test_onQueryChanged_300ms_지나야_autocomplete_상태로_전환() async {
        let recent = MockRecentKeywordUseCase()
        let autoComplete = MockAutoCompleteUseCase(stubSuggestions: [Self.keyword("swift", at: 1)])
        let clock = TestClock()
        let sut = makeSUT(recent: recent, autoComplete: autoComplete, clock: clock)

        sut.onQueryChanged("swif")

        // 디바운스 직전엔 아직 .recent 그대로
        await clock.advance(by: .milliseconds(299))
        XCTAssertEqual(sut.state, .recent([]))

        // 300ms 경계 통과 후 .autocomplete로 전환
        await clock.advance(by: .milliseconds(1))
        XCTAssertEqual(sut.state, .autocomplete([Self.keyword("swift", at: 1)]))
    }

    func test_onQueryChanged_빈_문자열은_debounce_없이_즉시_recent로_복귀() async {
        let recent = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let autoComplete = MockAutoCompleteUseCase()
        let sut = makeSUT(recent: recent, autoComplete: autoComplete)

        sut.onQueryChanged("")
        // 빈 입력 경로는 clock을 사용하지 않으므로 명시적으로 대기 (clock.advance에 의존하면 flaky).
        await sut.waitForPendingRefresh()

        XCTAssertEqual(sut.state, .recent([Self.keyword("swift", at: 1)]))
        let captured = await autoComplete.capturedPrefixes
        XCTAssertEqual(captured, [])
    }

    /// `.searchable` 취소 버튼은 query를 ""로 설정 → onQueryChanged("") 흐름과 동일.
    /// 결과 상태에서 빈 입력이 들어오면 자연스럽게 최근 검색으로 복귀해야 한다.
    func test_results_상태에서_빈_query가_들어오면_recent로_복귀() async {
        let recent = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let autoComplete = MockAutoCompleteUseCase()
        let sut = makeSUT(recent: recent, autoComplete: autoComplete)
        sut.query = "swift"
        await sut.onSubmit()
        guard case .results = sut.state else {
            XCTFail("선결 조건: .results 상태여야 함")
            return
        }

        sut.onQueryChanged("")
        await sut.waitForPendingRefresh()

        XCTAssertEqual(sut.state, .recent([Self.keyword("swift", at: 1)]))
    }

    /// 같은 query로 다시 submit하면 캐시된 SearchResultViewModel을 복원 →
    /// 스크롤/페이지네이션이 보존된다.
    func test_같은_query로_재진입하면_같은_SearchResultViewModel을_복원한다() async {
        let recent = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: recent)
        sut.query = "swift"
        await sut.onSubmit()
        let firstVM = producedResultViewModels[0]

        sut.onQueryChanged("")
        await sut.waitForPendingRefresh()
        XCTAssertEqual(sut.state, .recent([]))

        sut.query = "swift"
        await sut.onSubmit()

        // factory는 호출되지 않아야 한다(캐시 hit) — produced 배열은 그대로 1개.
        XCTAssertEqual(producedResultViewModels.count, 1)
        XCTAssertEqual(sut.state, .results(firstVM))
    }

    /// 다른 query로 submit하면 새 VM이 만들어지고 캐시가 교체된다.
    func test_다른_query로_재진입하면_새_SearchResultViewModel을_생성한다() async {
        let recent = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: recent)
        sut.query = "swift"
        await sut.onSubmit()
        sut.query = "kotlin"

        await sut.onSubmit()

        XCTAssertEqual(producedResultViewModels.count, 2)
        XCTAssertNotEqual(ObjectIdentifier(producedResultViewModels[0]),
                          ObjectIdentifier(producedResultViewModels[1]))
        XCTAssertEqual(sut.state, .results(producedResultViewModels[1]))
    }

    func test_onQueryChanged_연속_입력시_이전_task가_취소되어_마지막_입력만_적용() async {
        let recent = MockRecentKeywordUseCase()
        let autoComplete = MockAutoCompleteUseCase(stubSuggestions: [Self.keyword("kotlin", at: 1)])
        let clock = TestClock()
        let sut = makeSUT(recent: recent, autoComplete: autoComplete, clock: clock)

        sut.onQueryChanged("s")
        await clock.advance(by: .milliseconds(100))
        sut.onQueryChanged("sw")
        await clock.advance(by: .milliseconds(100))
        sut.onQueryChanged("kot")
        await clock.advance(by: .milliseconds(300))

        let captured = await autoComplete.capturedPrefixes
        XCTAssertEqual(captured, ["kot"])
        XCTAssertEqual(sut.state, .autocomplete([Self.keyword("kotlin", at: 1)]))
    }

    func test_onSubmit_은_진행중인_debounce를_취소한다() async {
        let recent = MockRecentKeywordUseCase()
        let autoComplete = MockAutoCompleteUseCase(stubSuggestions: [Self.keyword("autocomp", at: 1)])
        let clock = TestClock()
        let sut = makeSUT(recent: recent, autoComplete: autoComplete, clock: clock)

        sut.query = "swift"
        sut.onQueryChanged("swift")
        await sut.onSubmit()

        // onSubmit이 debounce를 취소했으므로 advance해도 autocomplete UseCase가 호출되지 않음
        await clock.advance(by: .milliseconds(500))

        let captured = await autoComplete.capturedPrefixes
        XCTAssertEqual(captured, [])
    }

    // MARK: - Helpers

    private func makeSUT(
        recent: MockRecentKeywordUseCase = MockRecentKeywordUseCase(),
        autoComplete: MockAutoCompleteUseCase = MockAutoCompleteUseCase(),
        clock: any Clock<Duration> = TestClock()
    ) -> SearchViewModel {
        SearchViewModel(
            recentKeywordUseCase: recent,
            autoCompleteUseCase: autoComplete,
            makeSearchResultViewModel: { [weak self] destination in
                let viewModel = SearchResultViewModel(
                    query: destination.query,
                    searchUseCase: MockSearchRepositoriesUseCase(stub: .success(Self.emptyResult))
                )
                self?.capturedDestinations.append(destination)
                self?.producedResultViewModels.append(viewModel)
                return viewModel
            },
            clock: clock
        )
    }

    private static func keyword(_ value: String, at: TimeInterval) -> RecentKeyword {
        RecentKeyword(keyword: value, searchedAt: Date(timeIntervalSince1970: at))
    }

    private static let emptyResult = SearchResult(
        totalCount: 0,
        repositories: [],
        page: 1,
        hasNextPage: false
    )
}
