import XCTest
import SearchInterface
import SearchTesting
@testable import Search

@MainActor
final class SearchViewModelTests: XCTestCase {

    // MARK: - onAppear

    func test_onAppear_state는_recent로_채워진다() async {
        let mock = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let sut = makeSUT(recent: mock)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .recent([Self.keyword("swift", at: 1)]))
    }

    // MARK: - onSubmit

    func test_onSubmit_query가_비어있으면_save도_router_호출도_없다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)
        var requested: String?
        sut.onRequestSearch = { requested = $0 }
        sut.query = ""

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, [])
        XCTAssertNil(requested)
    }

    func test_onSubmit_query가_공백뿐이면_save도_router_호출도_없다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)
        var requested: String?
        sut.onRequestSearch = { requested = $0 }
        sut.query = "   "

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, [])
        XCTAssertNil(requested)
    }

    func test_onSubmit_query를_trim해서_save_하고_router를_호출하고_query도_갱신된다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)
        var requested: String?
        sut.onRequestSearch = { requested = $0 }
        sut.query = "  swift  "

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, ["swift"])
        XCTAssertEqual(requested, "swift")
        XCTAssertEqual(sut.query, "swift")
    }

    func test_onSubmit_이후_state가_recent로_갱신된다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)
        sut.query = "swift"

        await mock.setStubRecent([Self.keyword("swift", at: 1)])
        await sut.onSubmit()

        XCTAssertEqual(sut.state, .recent([Self.keyword("swift", at: 1)]))
    }

    // MARK: - onTapRecent

    func test_onTapRecent_query_갱신_save_router_호출_state_갱신() async {
        let mock = MockRecentKeywordUseCase()
        let sut = makeSUT(recent: mock)
        var requested: String?
        sut.onRequestSearch = { requested = $0 }

        await mock.setStubRecent([Self.keyword("kotlin", at: 2)])
        await sut.onTapRecent("kotlin")

        XCTAssertEqual(sut.query, "kotlin")
        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, ["kotlin"])
        XCTAssertEqual(requested, "kotlin")
        XCTAssertEqual(sut.state, .recent([Self.keyword("kotlin", at: 2)]))
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

    func test_onQueryChanged_빈_문자열은_recent로_복귀() async {
        let recent = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let autoComplete = MockAutoCompleteUseCase()
        let clock = TestClock()
        let sut = makeSUT(recent: recent, autoComplete: autoComplete, clock: clock)

        sut.onQueryChanged("")

        await clock.advance(by: .milliseconds(300))

        XCTAssertEqual(sut.state, .recent([Self.keyword("swift", at: 1)]))
        let captured = await autoComplete.capturedPrefixes
        XCTAssertEqual(captured, [])
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
            clock: clock
        )
    }

    private static func keyword(_ value: String, at: TimeInterval) -> RecentKeyword {
        RecentKeyword(keyword: value, searchedAt: Date(timeIntervalSince1970: at))
    }
}
