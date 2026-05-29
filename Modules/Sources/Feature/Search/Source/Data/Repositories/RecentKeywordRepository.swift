import Foundation
import SearchInterface
import StorageInterface

/// `RecentKeywordRepositoryProtocol`의 KeyValueStorage 기반 구현체.
///
/// 저장 포맷: JSON 인코딩된 `[RecentKeyword]` 단일 키.
/// `searchedAt` 내림차순으로 보관하며, 동일 keyword를 다시 append하면 기존 entry를 제거하고
/// 새 date로 맨 앞에 삽입한다(dedupe + recency).
///
/// 상태는 actor 내부 `cache`에 보관한다. 모든 mutation은 cache를 동기 변경한 뒤 storage에 반영하므로
/// 동시 append/remove가 load→modify→save 인터리브로 한 쪽 변경분을 덮어쓰는 reentrancy race가 없다.
/// 첫 호출에서만 storage에서 load하고, 이후엔 cache가 source of truth.
public actor RecentKeywordRepository: RecentKeywordRepositoryProtocol {

    // MARK: - Constants

    private static let storageKey = "feature.search.recentKeywords.v1"

    // MARK: - State

    private let storage: KeyValueStorageProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cache: [RecentKeyword]?

    // MARK: - Init

    public init(
        storage: KeyValueStorageProtocol,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.storage = storage
        self.encoder = encoder
        self.decoder = decoder
    }

    // MARK: - RecentKeywordRepositoryProtocol

    public func all() async -> [RecentKeyword] {
        await ensureLoaded()
    }

    public func append(_ keyword: String, at date: Date) async {
        var items = await ensureLoaded()
        items.removeAll { $0.keyword == keyword }
        items.insert(RecentKeyword(keyword: keyword, searchedAt: date), at: 0)
        cache = items
        await persist(items)
    }

    public func remove(_ keyword: String) async {
        var items = await ensureLoaded()
        items.removeAll { $0.keyword == keyword }
        cache = items
        await persist(items)
    }

    public func removeAll() async {
        cache = []
        await storage.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Private

    private func ensureLoaded() async -> [RecentKeyword] {
        if let cache {
            return cache
        }
        let loaded = await loadFromStorage()
        cache = loaded
        return loaded
    }

    private func loadFromStorage() async -> [RecentKeyword] {
        guard let data = await storage.data(forKey: Self.storageKey),
              let decoded = try? decoder.decode([RecentKeyword].self, from: data) else {
            return []
        }
        return decoded
    }

    /// 인코딩 실패 시 storage를 건드리지 않는다. `setData(nil, ...)`는 키를 삭제하는 계약이므로
    /// 인코딩 에러가 사용자 기록 전체를 wipe하지 않도록 early return.
    private func persist(_ items: [RecentKeyword]) async {
        guard let data = try? encoder.encode(items) else {
            return
        }
        await storage.setData(data, forKey: Self.storageKey)
    }
}
