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

    /// 요구사항 1-2: 최근 검색어는 최대 10개까지만 보관·표시한다.
    /// append가 맨 앞 삽입 + 내림차순 유지이므로 prefix(maxCount)가 곧 "가장 오래된 것부터 제거".
    private static let maxCount = 10

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
        items = Array(items.prefix(Self.maxCount))
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
        // 디스크에 어떤 경로로 10개 초과가 들어있든(구버전 데이터 등) 읽는 시점에 불변식 강제.
        // 초과 시 디스크도 한 번 동기화(write-back)해 이후 cold start의 반복 디코딩을 막는다.
        guard decoded.count > Self.maxCount else { return decoded }
        let capped = Array(decoded.prefix(Self.maxCount))
        await persist(capped)
        return capped
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
