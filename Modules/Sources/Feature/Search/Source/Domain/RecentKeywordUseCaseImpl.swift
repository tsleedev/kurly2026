import Foundation
import SearchInterface

/// `RecentKeywordUseCase` 구현체.
///
/// 동시 호출이 적은 영역(검색 화면 유저 액션)이지만 thread-safe하게 동작하도록
/// underlying repository와 clock에만 의존하고 자체 상태는 보유하지 않는다.
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

    public func recent() -> [RecentKeyword] {
        repository.all().sorted { $0.searchedAt > $1.searchedAt }
    }

    public func save(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        repository.append(trimmed, at: clock())
    }

    public func delete(_ keyword: String) {
        repository.remove(keyword)
    }

    public func deleteAll() {
        repository.removeAll()
    }
}
