import Foundation
import SearchInterface

/// `RecentKeywordRepositoryProtocol` 테스트 대역. in-memory 저장소.
///
/// NSLock으로 _keywords를 보호한다.
/// @unchecked Sendable: lock 보호로 thread-safety를 직접 보장하므로 컴파일러 검사를 우회.
public final class MockRecentKeywordRepository: RecentKeywordRepositoryProtocol, @unchecked Sendable {

    // MARK: - State

    private var _keywords: [RecentKeyword] = []
    private let lock = NSLock()

    // MARK: - Init

    public init(initial: [RecentKeyword] = []) {
        self._keywords = initial
    }

    // MARK: - RecentKeywordRepositoryProtocol

    public func all() -> [RecentKeyword] {
        lock.withLock { _keywords }
    }

    public func append(_ keyword: String, at date: Date) {
        lock.withLock {
            // 동일 keyword가 있으면 교체 (중복 방지)
            _keywords.removeAll { $0.keyword == keyword }
            _keywords.append(RecentKeyword(keyword: keyword, searchedAt: date))
        }
    }

    public func remove(_ keyword: String) {
        lock.withLock {
            _keywords.removeAll { $0.keyword == keyword }
        }
    }

    public func removeAll() {
        lock.withLock { _keywords.removeAll() }
    }
}
