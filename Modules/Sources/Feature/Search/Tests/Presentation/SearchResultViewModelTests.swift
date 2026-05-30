import XCTest
import NetworkingInterface
import SearchInterface
import SearchTesting
@testable import Search

@MainActor
final class SearchResultViewModelTests: XCTestCase {

    // MARK: - onAppear / load

    func test_onAppear_정상응답이면_state가_loaded로_전환된다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .success(Self.sampleResult))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .loaded(Self.sampleResult))
    }

    func test_onAppear_NetworkError를_던지면_state가_failed로_전환된다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .failure(NetworkError.rateLimited(retryAfter: 30)))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .failed(.rateLimited(retryAfter: 30)))
    }

    func test_onAppear_NetworkError가_아닌_에러는_transport로_매핑된다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .failure(TestError.boom))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .failed(.transport))
    }

    func test_onAppear_CancellationError는_failed로_전환하지_않는다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .failure(CancellationError()))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .loading)
    }

    func test_onAppear_NetworkError_cancelled은_failed로_전환하지_않는다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .failure(NetworkError.cancelled))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)

        await sut.onAppear()

        XCTAssertEqual(sut.state, .loading)
    }

    func test_onAppear_cancelled_후_다시_호출하면_재시도된다() async {
        // 첫 시도는 cancelled, 두 번째는 정상
        let mock = MockSearchRepositoriesUseCase(stub: .failure(CancellationError()))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)
        await sut.onAppear()
        XCTAssertEqual(sut.state, .loading)

        await mock.setStub(.success(Self.sampleResult))
        await sut.onAppear()

        XCTAssertEqual(sut.state, .loaded(Self.sampleResult))
        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.count, 2)
    }

    func test_onAppear_page는_항상_1로_호출된다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .success(Self.sampleResult))
        let sut = SearchResultViewModel(query: "kotlin", searchUseCase: mock)

        await sut.onAppear()

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].query, "kotlin")
        XCTAssertEqual(captured[0].page, 1)
    }

    func test_onAppear_이미_loaded_상태면_재호출되지_않는다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .success(Self.sampleResult))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)
        await sut.onAppear()

        await sut.onAppear()

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.count, 1)
    }

    func test_onAppear_failed_상태면_자동_재호출되지_않는다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .failure(NetworkError.transport))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)
        await sut.onAppear()
        XCTAssertEqual(sut.state, .failed(.transport))

        // .task 재발화 등으로 onAppear가 다시 호출돼도 자동 재시도하지 않음 — 명시적 onRetry로만
        await sut.onAppear()

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.count, 1)
    }

    // MARK: - onRetry

    func test_onRetry_state가_loading으로_초기화된_후_재요청된다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .failure(NetworkError.transport))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)
        await sut.onAppear()
        XCTAssertEqual(sut.state, .failed(.transport))

        await mock.setStub(.success(Self.sampleResult))
        await sut.onRetry()

        XCTAssertEqual(sut.state, .loaded(Self.sampleResult))
        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.count, 2)
    }

    // MARK: - onTapRepository

    func test_onTapRepository_onRequestWebView_closure를_호출한다() async {
        let mock = MockSearchRepositoriesUseCase(stub: .success(Self.sampleResult))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)
        var requested: Repository?
        sut.onRequestWebView = { requested = $0 }
        let target = Self.sampleRepository(id: 99, name: "x")

        sut.onTapRepository(target)

        XCTAssertEqual(requested, target)
    }

    // MARK: - loadNextPageIfNeeded

    func test_loadNextPageIfNeeded_state가_loaded가_아니면_no_op() async {
        let mock = MockSearchRepositoriesUseCase(stub: .success(Self.sampleResult))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock)
        // state는 아직 .loading

        await sut.loadNextPageIfNeeded(currentItem: Self.sampleRepository(id: 1, name: "swift"))

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.count, 0)
    }

    func test_loadNextPageIfNeeded_hasNextPage가_false면_no_op() async {
        let firstPage = Self.makeResult(ids: 1...3, page: 1, hasNextPage: false, totalCount: 3)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 5)
        await sut.onAppear()

        await sut.loadNextPageIfNeeded(currentItem: firstPage.repositories.last ?? firstPage.repositories[0])

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.count, 1)
    }

    func test_loadNextPageIfNeeded_threshold_밖이면_no_op() async {
        let firstPage = Self.makeResult(ids: 1...10, page: 1, hasNextPage: true, totalCount: 30)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 3)
        await sut.onAppear()

        // index 0(끝에서 10번째)는 threshold(3) 밖
        await sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[0])

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.count, 1)
    }

    func test_loadNextPageIfNeeded_threshold_안이면_다음_페이지를_가져와_누적한다() async {
        let firstPage = Self.makeResult(ids: 1...10, page: 1, hasNextPage: true, totalCount: 30)
        let secondPage = Self.makeResult(ids: 11...20, page: 2, hasNextPage: true, totalCount: 30)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 3)
        await sut.onAppear()
        await mock.setStub(.success(secondPage))

        // 끝에서 3번째 안의 셀
        await sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[8])

        XCTAssertEqual(sut.paginationState, .idle)
        if case .loaded(let merged) = sut.state {
            XCTAssertEqual(merged.repositories.map(\.id), Array(1...20))
            XCTAssertEqual(merged.page, 2)
            XCTAssertTrue(merged.hasNextPage)
        } else {
            XCTFail("state must be .loaded")
        }
        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.map(\.page), [1, 2])
    }

    func test_loadNextPageIfNeeded_paginationState가_loading이면_중복_트리거하지_않는다() async {
        let firstPage = Self.makeResult(ids: 1...10, page: 1, hasNextPage: true, totalCount: 30)
        let secondPage = Self.makeResult(ids: 11...20, page: 2, hasNextPage: false, totalCount: 20)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 5)
        await sut.onAppear()
        await mock.setStub(.success(secondPage))

        // 같은 셀의 onAppear가 두 번 발화한 시나리오: 두 번째 호출은 paginationState 가드로 차단
        async let first: () = sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[7])
        async let second: () = sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[8])
        _ = await (first, second)

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.filter { $0.page == 2 }.count, 1)
    }

    func test_loadNextPageIfNeeded_실패시_paginationState가_failed() async {
        let firstPage = Self.makeResult(ids: 1...10, page: 1, hasNextPage: true, totalCount: 30)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 5)
        await sut.onAppear()
        await mock.setStub(.failure(NetworkError.rateLimited(retryAfter: 30)))

        await sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[8])

        XCTAssertEqual(sut.paginationState, .failed(.rateLimited(retryAfter: 30)))
        if case .loaded(let unchanged) = sut.state {
            XCTAssertEqual(unchanged.repositories.map(\.id), Array(1...10))
        } else {
            XCTFail("state는 기존 .loaded 유지여야 함")
        }
    }

    func test_loadNextPageIfNeeded_paginationState가_failed면_no_op() async {
        let firstPage = Self.makeResult(ids: 1...10, page: 1, hasNextPage: true, totalCount: 30)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 5)
        await sut.onAppear()
        await mock.setStub(.failure(NetworkError.transport))
        await sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[8])
        XCTAssertEqual(sut.paginationState, .failed(.transport))

        await sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[9])

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.filter { $0.page == 2 }.count, 1)
    }

    func test_loadNextPage_페이지_경계_중복_id는_dedup된다() async {
        // page 1: ids 1...10, page 2: ids 9...18 (id 9, 10 중복)
        let firstPage = Self.makeResult(ids: 1...10, page: 1, hasNextPage: true, totalCount: 18)
        let secondPage = Self.makeResult(ids: 9...18, page: 2, hasNextPage: false, totalCount: 18)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 5)
        await sut.onAppear()
        await mock.setStub(.success(secondPage))

        await sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[8])

        if case .loaded(let merged) = sut.state {
            XCTAssertEqual(merged.repositories.map(\.id), Array(1...18))
        } else {
            XCTFail("state must be .loaded")
        }
    }

    // MARK: - retryNextPage

    func test_retryNextPage_paginationState가_failed_상태에서_다음_페이지를_재요청한다() async {
        let firstPage = Self.makeResult(ids: 1...10, page: 1, hasNextPage: true, totalCount: 30)
        let secondPage = Self.makeResult(ids: 11...20, page: 2, hasNextPage: false, totalCount: 20)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 5)
        await sut.onAppear()
        await mock.setStub(.failure(NetworkError.transport))
        await sut.loadNextPageIfNeeded(currentItem: firstPage.repositories[8])

        await mock.setStub(.success(secondPage))
        await sut.retryNextPage()

        XCTAssertEqual(sut.paginationState, .idle)
        if case .loaded(let merged) = sut.state {
            XCTAssertEqual(merged.repositories.map(\.id), Array(1...20))
        } else {
            XCTFail("state must be .loaded")
        }
    }

    func test_retryNextPage_paginationState가_loading_상태면_no_op() async {
        let firstPage = Self.makeResult(ids: 1...10, page: 1, hasNextPage: true, totalCount: 30)
        let secondPage = Self.makeResult(ids: 11...20, page: 2, hasNextPage: false, totalCount: 20)
        let mock = MockSearchRepositoriesUseCase(stub: .success(firstPage))
        let sut = SearchResultViewModel(query: "swift", searchUseCase: mock, prefetchThreshold: 5)
        await sut.onAppear()
        await mock.setStub(.success(secondPage))

        // 두 번 동시에 호출 — 첫 호출이 loading 동안 두 번째는 가드로 차단
        async let first: () = sut.retryNextPage()
        async let second: () = sut.retryNextPage()
        _ = await (first, second)

        let captured = await mock.capturedExecutions
        XCTAssertEqual(captured.filter { $0.page == 2 }.count, 1)
    }

    // MARK: - Fixtures

    private static let sampleResult = SearchResult(
        totalCount: 2,
        repositories: [
            sampleRepository(id: 1, name: "swift"),
            sampleRepository(id: 2, name: "vapor"),
        ],
        page: 1,
        hasNextPage: false
    )

    private static let placeholderAvatar = URL(string: "https://example.com/a.png") ?? URL(fileURLWithPath: "/")
    private static let placeholderHTML = URL(string: "https://github.com/u/x") ?? URL(fileURLWithPath: "/")

    private static func sampleRepository(id: Int, name: String) -> Repository {
        Repository(
            id: id,
            name: name,
            fullName: "u/\(name)",
            owner: Owner(login: "u", avatarURL: placeholderAvatar),
            description: nil,
            htmlURL: placeholderHTML
        )
    }

    private static func makeResult(
        ids: ClosedRange<Int>,
        page: Int,
        hasNextPage: Bool,
        totalCount: Int
    ) -> SearchResult {
        SearchResult(
            totalCount: totalCount,
            repositories: ids.map { sampleRepository(id: $0, name: "r\($0)") },
            page: page,
            hasNextPage: hasNextPage
        )
    }
}

private enum TestError: Error {
    case boom
}
