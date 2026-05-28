import Foundation

/// GitHub Search API 접근 추상화.
public protocol GitHubRepositoryProtocol: Sendable {
    func search(query: String, page: Int) async throws -> SearchResult
}
