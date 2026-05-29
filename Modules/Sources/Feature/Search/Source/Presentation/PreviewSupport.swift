#if DEBUG && canImport(UIKit) && canImport(SwiftUI)
import Foundation
import UIKit
import NetworkInterface
import ImageLoadingInterface
import SearchInterface

// MARK: - Stub UseCases

/// Source 내부 Stub. SearchTesting 의 Mock 을 Source 가 import 하지 않기 위해 별도 정의한다
/// (Package.swift "Mock 외부 유출 방지" 정책 유지). `#if DEBUG` 가드로 Release 바이너리에서 제외.
struct StubRecentKeywordUseCase: RecentKeywordUseCase {
    let stub: [RecentKeyword]
    init(_ stub: [RecentKeyword]) { self.stub = stub }
    func recent() async -> [RecentKeyword] { stub }
    func save(_ keyword: String) async {}
    func delete(_ keyword: String) async {}
    func deleteAll() async {}
}

struct StubAutoCompleteUseCase: AutoCompleteUseCase {
    let stub: [RecentKeyword]
    init(_ stub: [RecentKeyword]) { self.stub = stub }
    func suggestions(for prefix: String) async -> [RecentKeyword] { stub }
}

struct StubSearchRepositoriesUseCase: SearchRepositoriesUseCase {
    enum Behavior: Sendable {
        case success(SearchResult)
        case failure(NetworkError)
        /// state 가 `.loading` 으로 유지되는 Preview 용. 영원히 await.
        case neverResolve
    }

    let behavior: Behavior
    init(_ behavior: Behavior) { self.behavior = behavior }

    func execute(query: String, page: Int) async throws -> SearchResult {
        switch behavior {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        case .neverResolve:
            try await Task.sleep(for: .seconds(1_000_000))
            return PreviewFixture.emptySearchResult
        }
    }
}

// MARK: - Stub ImageLoader

/// CachedAsyncImage 의 placeholder 가 계속 보이도록 영원히 await 한다.
/// 실제 네트워크 요청을 보내지 않아 Preview 의 결정론성 + 외부 의존 제거.
struct StubImageLoader: ImageLoaderProtocol {
    func image(for url: URL) async throws -> UIImage {
        try await Task.sleep(for: .seconds(1_000_000))
        return UIImage()
    }
    func cancel(for url: URL) async {}
}

// MARK: - Sample data

/// Preview / Canvas 에서 공통으로 쓰는 결정론적 fixture. 스냅샷 테스트 fixture 와 동일 컨셉.
enum PreviewFixture {
    static let recentKeywords: [RecentKeyword] = [
        RecentKeyword(keyword: "swift", searchedAt: Date(timeIntervalSince1970: 1_700_000_000)),
        RecentKeyword(keyword: "kotlin", searchedAt: Date(timeIntervalSince1970: 1_699_900_000)),
        RecentKeyword(keyword: "rust", searchedAt: Date(timeIntervalSince1970: 1_699_800_000)),
    ]

    static let repositories: [Repository] = [
        Repository(
            id: 1,
            name: "swift",
            fullName: "apple/swift",
            owner: Owner(login: "apple", avatarURL: url("https://avatars.githubusercontent.com/u/10639145?v=4")),
            description: "The Swift Programming Language",
            htmlURL: url("https://github.com/apple/swift")
        ),
        Repository(
            id: 2,
            name: "vapor",
            fullName: "vapor/vapor",
            owner: Owner(login: "vapor", avatarURL: url("https://avatars.githubusercontent.com/u/17364220?v=4")),
            description: "A server-side Swift HTTP web framework",
            htmlURL: url("https://github.com/vapor/vapor")
        ),
        Repository(
            id: 3,
            name: "Alamofire",
            fullName: "Alamofire/Alamofire",
            owner: Owner(login: "Alamofire", avatarURL: url("https://avatars.githubusercontent.com/u/7774181?v=4")),
            description: "Elegant HTTP Networking in Swift",
            htmlURL: url("https://github.com/Alamofire/Alamofire")
        ),
    ]

    static let searchResult = SearchResult(
        totalCount: 266_714,
        repositories: repositories,
        page: 1,
        hasNextPage: true
    )

    static let emptySearchResult = SearchResult(
        totalCount: 0,
        repositories: [],
        page: 1,
        hasNextPage: false
    )

    /// force_unwrapping SwiftLint 룰 회피용 URL 헬퍼.
    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }
}

// MARK: - Preview helpers

/// SearchView Preview 에서 .results state 진입 시 SearchResultViewModel 을 즉석 생성한다.
/// Live Preview / Interactive Preview 모드에서 검색어 탭 또는 submit 으로 결과 화면이 열릴 때
/// crash 없이 stub 결과를 표시하기 위한 factory (이전 `fatalError` 대체).
@MainActor
func previewMakeSearchResultViewModel(_ destination: SearchResultDestination) -> SearchResultViewModel {
    SearchResultViewModel(
        query: destination.query,
        searchUseCase: StubSearchRepositoriesUseCase(.success(PreviewFixture.searchResult))
    )
}
#endif
