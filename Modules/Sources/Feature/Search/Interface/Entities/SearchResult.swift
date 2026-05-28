import Foundation

/// GitHub 저장소 검색 결과 페이지.
public struct SearchResult: Equatable, Sendable {
    public let totalCount: Int
    public let repositories: [Repository]
    public let page: Int
    public let hasNextPage: Bool

    public init(
        totalCount: Int,
        repositories: [Repository],
        page: Int,
        hasNextPage: Bool
    ) {
        self.totalCount = totalCount
        self.repositories = repositories
        self.page = page
        self.hasNextPage = hasNextPage
    }
}
