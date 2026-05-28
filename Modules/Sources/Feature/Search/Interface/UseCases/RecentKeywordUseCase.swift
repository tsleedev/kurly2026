import Foundation

/// 최근 검색어 CRUD를 담당한다.
public protocol RecentKeywordUseCase: Sendable {
    func recent() -> [RecentKeyword]
    func save(_ keyword: String)
    func delete(_ keyword: String)
    func deleteAll()
}
