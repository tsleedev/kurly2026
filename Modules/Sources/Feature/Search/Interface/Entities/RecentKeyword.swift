import Foundation

/// 최근 검색 키워드.
public struct RecentKeyword: Equatable, Codable, Hashable, Sendable {
    public let keyword: String
    public let searchedAt: Date

    public init(keyword: String, searchedAt: Date) {
        self.keyword = keyword
        self.searchedAt = searchedAt
    }
}
