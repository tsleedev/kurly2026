#if canImport(UIKit)
import XCTest
import SnapshotTesting
import SwiftUI
import ImageLoadingTesting
import NetworkInterface
import SearchInterface
import SearchTesting
@testable import Search

@MainActor
final class SearchResultViewSnapshotTests: XCTestCase {

    private let layout: SwiftUISnapshotLayout = .device(config: .iPhone17)
    private let precision: Float = 0.99

    // MARK: - State 변화

    func test_loading_상태() {
        let viewModel = makeViewModel(stub: .success(Self.emptyResult))
        // onAppear 호출 안 함 — 초기 .loading 상태 그대로

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    func test_loaded_저장소_N개() async {
        let viewModel = makeViewModel(stub: .success(Self.sampleResult))
        await viewModel.onAppear()

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    func test_loaded_빈_결과() async {
        let emptyResult = SearchResult(totalCount: 0, repositories: [], page: 1, hasNextPage: false)
        let viewModel = makeViewModel(stub: .success(emptyResult), query: "no-such-thing")
        await viewModel.onAppear()

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    func test_failed_상태_rate_limited() async {
        let viewModel = makeViewModel(stub: .failure(NetworkError.rateLimited(retryAfter: 30)))
        await viewModel.onAppear()

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    func test_failed_상태_transport() async {
        let viewModel = makeViewModel(stub: .failure(NetworkError.transport))
        await viewModel.onAppear()

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    // MARK: - Helpers

    private func makeViewModel(
        stub: Result<SearchResult, Error>,
        query: String = "swift"
    ) -> SearchResultViewModel {
        let useCase = MockSearchRepositoriesUseCase(stub: stub)
        return SearchResultViewModel(query: query, searchUseCase: useCase)
    }

    private func hosted(_ viewModel: SearchResultViewModel) -> some View {
        NavigationStack {
            SearchResultView(viewModel: viewModel, imageLoader: MockImageLoader())
        }
    }

    // MARK: - Fixtures

    private static let placeholderAvatar = URL(string: "https://example.com/a.png") ?? URL(fileURLWithPath: "/")
    private static let placeholderHTML = URL(string: "https://github.com/u/x") ?? URL(fileURLWithPath: "/")

    private static let emptyResult = SearchResult(
        totalCount: 0,
        repositories: [],
        page: 1,
        hasNextPage: false
    )

    private static let sampleResult = SearchResult(
        totalCount: 266_714,
        repositories: [
            sampleRepository(id: 1, name: "swift", owner: "apple", description: "The Swift Programming Language"),
            sampleRepository(id: 2, name: "vapor", owner: "vapor", description: "💧 A server-side Swift HTTP web framework."),
            sampleRepository(id: 3, name: "Alamofire", owner: "Alamofire", description: "Elegant HTTP Networking in Swift"),
        ],
        page: 1,
        hasNextPage: true
    )

    private static func sampleRepository(id: Int, name: String, owner: String, description: String?) -> Repository {
        Repository(
            id: id,
            name: name,
            fullName: "\(owner)/\(name)",
            owner: Owner(login: owner, avatarURL: placeholderAvatar),
            description: description,
            htmlURL: placeholderHTML
        )
    }
}
#endif
