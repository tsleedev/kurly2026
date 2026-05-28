import Foundation
import SearchInterface

/// `SearchRepositoriesUseCase` 구현체. Repository에 위임한다.
public final class SearchRepositoriesUseCaseImpl: SearchRepositoriesUseCase {

    // MARK: - Init

    private let repository: GitHubRepositoryProtocol

    public init(repository: GitHubRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Public

    public func execute(query: String, page: Int) async throws -> SearchResult {
        try await repository.search(query: query, page: page)
    }
}
