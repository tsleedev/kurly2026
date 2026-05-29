import XCTest
import NetworkInterface
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

    private static let placeholderAvatar = URL(string: "https://example.com/a.png")!
    private static let placeholderHTML = URL(string: "https://github.com/u/x")!

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
}

private enum TestError: Error {
    case boom
}
