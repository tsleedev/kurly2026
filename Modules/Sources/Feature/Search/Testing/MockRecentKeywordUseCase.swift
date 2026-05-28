import Foundation
import SearchInterface

/// `RecentKeywordUseCase` 테스트 대역.
///
/// actor로 선언하여 stubRecent / captured* 프로퍼티를 actor isolation으로 보호한다.
/// NSLock + @unchecked Sendable 패턴을 제거하고 컴파일러 수준의 thread-safety를 얻는다.
public actor MockRecentKeywordUseCase: RecentKeywordUseCase {

    // MARK: - Stub

    public var stubRecent: [RecentKeyword]

    // MARK: - Captured

    public private(set) var capturedSaves: [String] = []
    public private(set) var capturedDeletes: [String] = []
    public private(set) var deleteAllCallCount: Int = 0

    // MARK: - Init

    public init(stubRecent: [RecentKeyword] = []) {
        self.stubRecent = stubRecent
    }

    // MARK: - RecentKeywordUseCase

    public func recent() -> [RecentKeyword] {
        stubRecent
    }

    public func save(_ keyword: String) {
        capturedSaves.append(keyword)
    }

    public func delete(_ keyword: String) {
        capturedDeletes.append(keyword)
    }

    public func deleteAll() {
        deleteAllCallCount += 1
    }

    // MARK: - Test Helpers

    public func setStubRecent(_ keywords: [RecentKeyword]) {
        stubRecent = keywords
    }
}
