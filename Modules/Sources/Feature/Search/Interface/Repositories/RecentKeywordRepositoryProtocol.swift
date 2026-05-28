import Foundation

/// 최근 검색어 영속성 추상화.
public protocol RecentKeywordRepositoryProtocol: Sendable {
    func all() -> [RecentKeyword]
    func append(_ keyword: String, at date: Date)
    func remove(_ keyword: String)
    func removeAll()
}
