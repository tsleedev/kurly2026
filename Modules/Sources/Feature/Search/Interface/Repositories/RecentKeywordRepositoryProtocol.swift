import Foundation

/// 최근 검색어 영속성 추상화.
///
/// 모든 메서드가 async로 정의되어 있으므로 구현체는 actor를 채택할 수 있다.
public protocol RecentKeywordRepositoryProtocol: Sendable {
    func all() async -> [RecentKeyword]
    func append(_ keyword: String, at date: Date) async
    func remove(_ keyword: String) async
    func removeAll() async
}
