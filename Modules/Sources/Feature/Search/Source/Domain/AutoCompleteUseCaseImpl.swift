import Foundation
import SearchInterface

/// `AutoCompleteUseCase` 구현체. prefix 매칭(대소문자 무시) + 최신순 + maxCount 제한.
///
/// 자체 mutable state 없이 repository에 위임만 하므로 final class로 충분하다.
public final class AutoCompleteUseCaseImpl: AutoCompleteUseCase {

    // MARK: - Init

    private let repository: RecentKeywordRepositoryProtocol
    private let maxCount: Int

    public init(repository: RecentKeywordRepositoryProtocol, maxCount: Int = 10) {
        self.repository = repository
        self.maxCount = maxCount
    }

    // MARK: - Public

    public func suggestions(for prefix: String) async -> [RecentKeyword] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lowered = trimmed.lowercased()
        return Array(
            (await repository.all())
                .filter { $0.keyword.lowercased().hasPrefix(lowered) }
                .sorted { $0.searchedAt > $1.searchedAt }
                .prefix(maxCount)
        )
    }
}
