import Foundation

/// 입력 prefix에 매칭되는 최근 검색어 제안을 반환한다.
///
/// async로 정의하여 구현체가 actor를 채택할 수 있도록 한다.
public protocol AutoCompleteUseCase: Sendable {
    func suggestions(for prefix: String) async -> [RecentKeyword]
}
