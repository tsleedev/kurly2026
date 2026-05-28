import Foundation

/// GitHub 저장소를 검색한다.
public protocol SearchRepositoriesUseCase: Sendable {
    func execute(query: String, page: Int) async throws -> SearchResult
}
