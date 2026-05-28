import Foundation
import SearchInterface

/// `RecentKeywordUseCase` 테스트 대역.
///
/// NSLock으로 captured* 프로퍼티를 보호한다.
/// @unchecked Sendable: lock 보호로 thread-safety를 직접 보장하므로 컴파일러 검사를 우회.
public final class MockRecentKeywordUseCase: RecentKeywordUseCase, @unchecked Sendable {

    // MARK: - Stub

    public var stubRecent: [RecentKeyword]

    // MARK: - Captured

    public private(set) var capturedSaves: [String] = []
    public private(set) var capturedDeletes: [String] = []
    public private(set) var deleteAllCallCount: Int = 0

    // MARK: - Init

    private let lock = NSLock()

    public init(stubRecent: [RecentKeyword] = []) {
        self.stubRecent = stubRecent
    }

    // MARK: - RecentKeywordUseCase

    public func recent() -> [RecentKeyword] {
        lock.withLock { stubRecent }
    }

    public func save(_ keyword: String) {
        lock.withLock { capturedSaves.append(keyword) }
    }

    public func delete(_ keyword: String) {
        lock.withLock { capturedDeletes.append(keyword) }
    }

    public func deleteAll() {
        lock.withLock { deleteAllCallCount += 1 }
    }
}
