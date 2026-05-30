import Foundation
import NetworkingInterface
import SearchInterface

/// `GitHubRepositoryProtocol`의 GitHub Search API 구현체.
public final class GitHubRepository: GitHubRepositoryProtocol {

    // MARK: - Init

    private let client: APIClientProtocol

    public init(client: APIClientProtocol) {
        self.client = client
    }

    // MARK: - GitHubRepositoryProtocol

    public func search(query: String, page: Int) async throws -> SearchResult {
        let endpoint = GitHubSearchEndpoint.searchRepositories(
            query: query,
            page: page,
            perPage: SearchResultMapper.perPage
        )
        let dto: SearchResultDTO = try await client.request(endpoint)
        return SearchResultMapper.map(dto, page: page)
    }
}
