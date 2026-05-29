import XCTest
import NetworkInterface
import NetworkTesting
import SearchInterface
@testable import Search

final class GitHubRepositoryTests: XCTestCase {

    // MARK: - Endpoint 구성

    func test_search_endpoint의_path와_쿼리가_GitHub_Search_명세를_따른다() async throws {
        let client = MockAPIClient()
        client.stub(result: Self.emptyDTO)
        let sut = GitHubRepository(client: client)

        _ = try await sut.search(query: "kurly", page: 3)

        let endpoint = try XCTUnwrap(client.capturedEndpoints.first)
        let url = try XCTUnwrap(endpoint.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []

        XCTAssertEqual(components.host, "api.github.com")
        XCTAssertEqual(components.path, "/search/repositories")
        XCTAssertEqual(items.first { $0.name == "q" }?.value, "kurly")
        XCTAssertEqual(items.first { $0.name == "page" }?.value, "3")
        XCTAssertEqual(items.first { $0.name == "per_page" }?.value, "30")
    }

    func test_search_endpoint에_GitHub_API_헤더가_포함된다() async throws {
        let client = MockAPIClient()
        client.stub(result: Self.emptyDTO)
        let sut = GitHubRepository(client: client)

        _ = try await sut.search(query: "swift", page: 1)

        let endpoint = try XCTUnwrap(client.capturedEndpoints.first)
        let headers = endpoint.headers ?? [:]
        XCTAssertEqual(headers["Accept"], "application/vnd.github+json")
        XCTAssertEqual(headers["X-GitHub-Api-Version"], "2022-11-28")
        XCTAssertEqual(headers["User-Agent"], "KurlyGitHubSearchApp")
    }

    func test_search_method는_GET() async throws {
        let client = MockAPIClient()
        client.stub(result: Self.emptyDTO)
        let sut = GitHubRepository(client: client)

        _ = try await sut.search(query: "swift", page: 1)

        let endpoint = try XCTUnwrap(client.capturedEndpoints.first)
        XCTAssertEqual(endpoint.method, .get)
    }

    // MARK: - 매핑

    func test_search_정상응답이면_매핑된_SearchResult를_반환한다() async throws {
        let client = MockAPIClient()
        client.stub(result: Self.twoItemDTO)
        let sut = GitHubRepository(client: client)

        let result = try await sut.search(query: "swift", page: 1)

        XCTAssertEqual(result.totalCount, 2)
        XCTAssertEqual(result.repositories.count, 2)
        XCTAssertEqual(result.repositories.first?.fullName, "apple/swift")
        XCTAssertEqual(result.page, 1)
        XCTAssertFalse(result.hasNextPage)
    }

    func test_search_요청한_page가_결과_page에_반영된다() async throws {
        let client = MockAPIClient()
        client.stub(result: Self.emptyDTO)
        let sut = GitHubRepository(client: client)

        let result = try await sut.search(query: "swift", page: 5)

        XCTAssertEqual(result.page, 5)
    }

    // MARK: - 에러 전파

    func test_search_API_에러는_그대로_전파된다() async throws {
        let client = MockAPIClient()
        client.stubError(NetworkError.statusCode(422))
        let sut = GitHubRepository(client: client)

        do {
            _ = try await sut.search(query: "swift", page: 1)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .statusCode(422))
        }
    }

    func test_search_매핑_실패는_decoding_에러로_던진다() async throws {
        let client = MockAPIClient()
        client.stub(result: Self.invalidURLDTO)
        let sut = GitHubRepository(client: client)

        do {
            _ = try await sut.search(query: "swift", page: 1)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .decoding)
        }
    }

    // MARK: - Fixtures

    private static let emptyDTO = SearchResultDTO(totalCount: 0, items: [])

    private static let twoItemDTO = SearchResultDTO(
        totalCount: 2,
        items: [
            RepositoryDTO(
                id: 1,
                name: "swift",
                fullName: "apple/swift",
                owner: OwnerDTO(login: "apple", avatarURL: "https://avatars.githubusercontent.com/u/10639145"),
                description: "The Swift Programming Language",
                htmlURL: "https://github.com/apple/swift"
            ),
            RepositoryDTO(
                id: 2,
                name: "vapor",
                fullName: "vapor/vapor",
                owner: OwnerDTO(login: "vapor", avatarURL: "https://avatars.githubusercontent.com/u/17364220"),
                description: nil,
                htmlURL: "https://github.com/vapor/vapor"
            ),
        ]
    )

    private static let invalidURLDTO = SearchResultDTO(
        totalCount: 1,
        items: [
            RepositoryDTO(
                id: 1,
                name: "x",
                fullName: "u/x",
                owner: OwnerDTO(login: "u", avatarURL: ""),
                description: nil,
                htmlURL: "https://github.com/u/x"
            ),
        ]
    )
}
