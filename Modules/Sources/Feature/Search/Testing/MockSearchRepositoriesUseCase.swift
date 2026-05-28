import Foundation
import SearchInterface

/// `SearchRepositoriesUseCase` 테스트 대역.
///
/// actor로 선언하여 stubResult / capturedExecutions를 actor isolation으로 보호한다.
/// NSLock + @unchecked Sendable 패턴을 제거하고 컴파일러 수준의 thread-safety를 얻는다.
public actor MockSearchRepositoriesUseCase: SearchRepositoriesUseCase {

    // MARK: - Stub

    public var stubResult: Result<SearchResult, Error>

    // MARK: - Captured

    /// `execute(query:page:)` 호출 이력. (query, page) 순서.
    public private(set) var capturedExecutions: [(query: String, page: Int)] = []

    // MARK: - Init

    public init(stub: Result<SearchResult, Error>) {
        self.stubResult = stub
    }

    // MARK: - SearchRepositoriesUseCase

    public func execute(query: String, page: Int) async throws -> SearchResult {
        capturedExecutions.append((query: query, page: page))
        switch stubResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Test Helpers

    public func setStub(_ stub: Result<SearchResult, Error>) {
        stubResult = stub
    }
}
