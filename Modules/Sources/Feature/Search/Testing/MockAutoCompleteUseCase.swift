import Foundation
import SearchInterface

/// `AutoCompleteUseCase` 테스트 대역.
///
/// NSLock으로 captured* 프로퍼티를 보호한다.
/// @unchecked Sendable: lock 보호로 thread-safety를 직접 보장하므로 컴파일러 검사를 우회.
public final class MockAutoCompleteUseCase: AutoCompleteUseCase, @unchecked Sendable {

    // MARK: - Stub

    public var stubSuggestions: [RecentKeyword]

    // MARK: - Captured

    public private(set) var capturedPrefixes: [String] = []

    // MARK: - Init

    private let lock = NSLock()

    public init(stubSuggestions: [RecentKeyword] = []) {
        self.stubSuggestions = stubSuggestions
    }

    // MARK: - AutoCompleteUseCase

    public func suggestions(for prefix: String) -> [RecentKeyword] {
        lock.withLock {
            capturedPrefixes.append(prefix)
            return stubSuggestions
        }
    }
}
