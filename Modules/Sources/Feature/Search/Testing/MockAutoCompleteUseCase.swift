import Foundation
import SearchInterface

/// `AutoCompleteUseCase` 테스트 대역.
///
/// actor로 선언하여 stubSuggestions / capturedPrefixes를 actor isolation으로 보호한다.
/// NSLock + @unchecked Sendable 패턴을 제거하고 컴파일러 수준의 thread-safety를 얻는다.
public actor MockAutoCompleteUseCase: AutoCompleteUseCase {

    // MARK: - Stub

    public var stubSuggestions: [RecentKeyword]

    // MARK: - Captured

    public private(set) var capturedPrefixes: [String] = []

    // MARK: - Init

    public init(stubSuggestions: [RecentKeyword] = []) {
        self.stubSuggestions = stubSuggestions
    }

    // MARK: - AutoCompleteUseCase

    public func suggestions(for prefix: String) -> [RecentKeyword] {
        capturedPrefixes.append(prefix)
        return stubSuggestions
    }

    // MARK: - Test Helpers

    public func setStubSuggestions(_ suggestions: [RecentKeyword]) {
        stubSuggestions = suggestions
    }
}
