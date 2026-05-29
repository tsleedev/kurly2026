import Foundation
import SearchInterface
import StorageInterface

/// `RecentKeywordRepositoryProtocol`의 KeyValueStorage 기반 구현체.
///
/// 저장 포맷: JSON 인코딩된 `[RecentKeyword]` 단일 키.
/// `searchedAt` 내림차순으로 보관하며, 동일 keyword를 다시 append하면 기존 entry를 제거하고
/// 새 date로 맨 앞에 삽입한다(dedupe + recency).
///
/// actor로 선언하여 캐시 갱신/저장 사이의 race를 actor isolation으로 차단한다.
public actor RecentKeywordRepository: RecentKeywordRepositoryProtocol {

    // MARK: - Constants

    private static let storageKey = "feature.search.recentKeywords.v1"

    // MARK: - Init

    private let storage: KeyValueStorageProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

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
        await load()
    }

    public func append(_ keyword: String, at date: Date) async {
        var current = await load()
        current.removeAll { $0.keyword == keyword }
        current.insert(RecentKeyword(keyword: keyword, searchedAt: date), at: 0)
        await save(current)
    }

    public func remove(_ keyword: String) async {
        var current = await load()
        current.removeAll { $0.keyword == keyword }
        await save(current)
    }

    public func removeAll() async {
        await storage.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Private

    private func load() async -> [RecentKeyword] {
        guard let data = await storage.data(forKey: Self.storageKey),
              let decoded = try? decoder.decode([RecentKeyword].self, from: data) else {
            return []
        }
        return decoded
    }

    private func save(_ items: [RecentKeyword]) async {
        let data = try? encoder.encode(items)
        await storage.setData(data, forKey: Self.storageKey)
    }
}
