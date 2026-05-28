import Foundation

/// 입력 prefix에 매칭되는 최근 검색어 제안을 반환한다.
public protocol AutoCompleteUseCase: Sendable {
    func suggestions(for prefix: String) -> [RecentKeyword]
}
