import Foundation
import SearchInterface

/// `GitHubRepositoryProtocol` 테스트 대역.
///
/// NSLock으로 captured* 프로퍼티를 보호한다.
/// @unchecked Sendable: lock 보호로 thread-safety를 직접 보장하므로 컴파일러 검사를 우회.
public final class MockGitHubRepository: GitHubRepositoryProtocol, @unchecked Sendable {

    // MARK: - Stub

    public var stubResult: Result<SearchResult, Error>

    // MARK: - Captured

    /// `search(query:page:)` 호출 이력. (query, page) 순서.
    public private(set) var capturedQueries: [(query: String, page: Int)] = []

    // MARK: - Init

    private let lock = NSLock()

    public init(stub: Result<SearchResult, Error>) {
        self.stubResult = stub
    }

    // MARK: - GitHubRepositoryProtocol

    public func search(query: String, page: Int) async throws -> SearchResult {
        lock.withLock {
            capturedQueries.append((query: query, page: page))
        }
        switch stubResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}
