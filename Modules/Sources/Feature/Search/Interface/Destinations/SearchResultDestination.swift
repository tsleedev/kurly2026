import Foundation

/// AppRouter가 검색 결과 화면으로 push할 때 들고 다니는 식별값.
///
/// 본 Interface에 두는 이유: AppRouter는 Feature Source에 의존하지 않고
/// Interface의 Destination struct만 직접 보유한다(plan.md "Router 패턴" 참조).
public struct SearchResultDestination: Hashable, Sendable {
    public let query: String

    public init(query: String) {
        self.query = query
    }
}
