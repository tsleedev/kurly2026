import Foundation
import SearchInterface

/// `RecentKeywordUseCase` 구현체.
///
/// 자체 mutable state 없이 repository에 위임만 하므로 final class로 충분하다.
/// protocol이 async 통일되어 있어 repository 호출에 await를 사용한다.
public final class RecentKeywordUseCaseImpl: RecentKeywordUseCase {

    // MARK: - Init

    private let repository: RecentKeywordRepositoryProtocol
    private let clock: @Sendable () -> Date

    public init(
        repository: RecentKeywordRepositoryProtocol,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.clock = clock
    }

    // MARK: - Public

    public func recent() async -> [RecentKeyword] {
        await repository.all().sorted { $0.searchedAt > $1.searchedAt }
    }

    public func save(_ keyword: String) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await repository.append(trimmed, at: clock())
    }

    public func delete(_ keyword: String) async {
        await repository.remove(keyword)
    }

    public func deleteAll() async {
        await repository.removeAll()
    }
}
