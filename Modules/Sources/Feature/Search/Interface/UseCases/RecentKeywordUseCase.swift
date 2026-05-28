import Foundation

/// 최근 검색어 CRUD를 담당한다.
///
/// 모든 메서드가 async로 정의되어 있으므로 구현체는 actor를 채택할 수 있다.
public protocol RecentKeywordUseCase: Sendable {
    func recent() async -> [RecentKeyword]
    func save(_ keyword: String) async
    func delete(_ keyword: String) async
    func deleteAll() async
}
