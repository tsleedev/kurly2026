import Foundation
import SearchInterface

/// `RecentKeywordRepositoryProtocol` 테스트 대역. in-memory 저장소.
///
/// actor로 선언하여 _keywords를 actor isolation으로 보호한다.
/// NSLock + @unchecked Sendable 패턴을 제거하고 컴파일러 수준의 thread-safety를 얻는다.
public actor MockRecentKeywordRepository: RecentKeywordRepositoryProtocol {

    // MARK: - State

    private var keywords: [RecentKeyword] = []

    // MARK: - Init

    public init(initial: [RecentKeyword] = []) {
        self.keywords = initial
    }

    // MARK: - RecentKeywordRepositoryProtocol

    public func all() -> [RecentKeyword] {
        keywords
    }

    public func append(_ keyword: String, at date: Date) {
        // 동일 keyword가 있으면 교체 (중복 방지)
        keywords.removeAll { $0.keyword == keyword }
        keywords.append(RecentKeyword(keyword: keyword, searchedAt: date))
    }

    public func remove(_ keyword: String) {
        keywords.removeAll { $0.keyword == keyword }
    }

    public func removeAll() {
        keywords.removeAll()
    }
}
