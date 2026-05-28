import XCTest
import SearchInterface
import SearchTesting
@testable import Search

final class SearchRepositoriesUseCaseTests: XCTestCase {

    // MARK: - 정상 응답

    func test_execute_정상응답이면_SearchResult를_반환한다() async throws {
        let stub = SearchResult.sample
        let mockRepo = MockGitHubRepository(stub: .success(stub))
        let sut = SearchRepositoriesUseCaseImpl(repository: mockRepo)

        let result = try await sut.execute(query: "swift", page: 1)

        XCTAssertEqual(result.totalCount, stub.totalCount)
        XCTAssertEqual(result.repositories.count, stub.repositories.count)
    }

    // MARK: - 실패 응답

    func test_execute_stubError가_있으면_에러를_던진다() async {
        let mockRepo = MockGitHubRepository(stub: .failure(TestError.stub))
        let sut = SearchRepositoriesUseCaseImpl(repository: mockRepo)

        do {
            _ = try await sut.execute(query: "swift", page: 1)
            XCTFail("에러를 던져야 합니다")
        } catch let error as TestError {
            XCTAssertEqual(error, .stub)
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    // MARK: - query/page 전달

    func test_execute_query와_page가_repository에_그대로_전달된다() async throws {
        let mockRepo = MockGitHubRepository(stub: .success(.sample))
        let sut = SearchRepositoriesUseCaseImpl(repository: mockRepo)

        _ = try await sut.execute(query: "kurly", page: 3)

        XCTAssertEqual(mockRepo.capturedQueries.count, 1)
        XCTAssertEqual(mockRepo.capturedQueries[0].query, "kurly")
        XCTAssertEqual(mockRepo.capturedQueries[0].page, 3)
    }

    func test_execute_page1과_page2가_각각_올바르게_전달된다() async throws {
        let mockRepo = MockGitHubRepository(stub: .success(.sample))
        let sut = SearchRepositoriesUseCaseImpl(repository: mockRepo)

        _ = try await sut.execute(query: "swift", page: 1)
        _ = try await sut.execute(query: "swift", page: 2)

        XCTAssertEqual(mockRepo.capturedQueries.count, 2)
        XCTAssertEqual(mockRepo.capturedQueries[0].page, 1)
        XCTAssertEqual(mockRepo.capturedQueries[1].page, 2)
    }
}

// MARK: - Fixtures

private extension SearchResult {
    static let sample = SearchResult(
        totalCount: 266_714,
        repositories: [
            Repository(
                id: 44_838_949,
                name: "swift",
                fullName: "apple/swift",
                owner: Owner(
                    login: "apple",
                    avatarURL: URL(string: "https://avatars.githubusercontent.com/u/10639145")!
                ),
                description: "The Swift Programming Language",
                htmlURL: URL(string: "https://github.com/apple/swift")!
            ),
        ],
        page: 1,
        hasNextPage: true
    )
}

private enum TestError: Error, Equatable {
    case stub
}
