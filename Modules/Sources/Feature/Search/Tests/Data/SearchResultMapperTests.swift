import XCTest
import NetworkInterface
import SearchInterface
@testable import Search

final class SearchResultMapperTests: XCTestCase {

    // MARK: - Owner

    func test_owner_avatarURL_파싱() throws {
        let dto = OwnerDTO(login: "apple", avatarURL: "https://avatars.githubusercontent.com/u/10639145")
        let owner = try SearchResultMapper.map(dto)
        XCTAssertEqual(owner.login, "apple")
        XCTAssertEqual(owner.avatarURL.absoluteString, "https://avatars.githubusercontent.com/u/10639145")
    }

    func test_owner_avatarURL_빈_문자열이면_decoding_에러() {
        let dto = OwnerDTO(login: "x", avatarURL: "")
        XCTAssertThrowsError(try SearchResultMapper.map(dto)) { error in
            XCTAssertEqual(error as? NetworkError, .decoding)
        }
    }

    // MARK: - Repository

    func test_repository_정상_매핑() throws {
        let dto = RepositoryDTO(
            id: 1,
            name: "swift",
            fullName: "apple/swift",
            owner: OwnerDTO(login: "apple", avatarURL: "https://example.com/a.png"),
            description: "The Swift Programming Language",
            htmlURL: "https://github.com/apple/swift"
        )

        let repo = try SearchResultMapper.map(dto)

        XCTAssertEqual(repo.id, 1)
        XCTAssertEqual(repo.name, "swift")
        XCTAssertEqual(repo.fullName, "apple/swift")
        XCTAssertEqual(repo.owner.login, "apple")
        XCTAssertEqual(repo.description, "The Swift Programming Language")
        XCTAssertEqual(repo.htmlURL.absoluteString, "https://github.com/apple/swift")
    }

    func test_repository_description_nil_허용() throws {
        let dto = RepositoryDTO(
            id: 1,
            name: "x",
            fullName: "u/x",
            owner: OwnerDTO(login: "u", avatarURL: "https://example.com/a.png"),
            description: nil,
            htmlURL: "https://github.com/u/x"
        )

        let repo = try SearchResultMapper.map(dto)

        XCTAssertNil(repo.description)
    }

    func test_repository_htmlURL_파싱_실패시_decoding_에러() {
        let dto = RepositoryDTO(
            id: 1,
            name: "x",
            fullName: "u/x",
            owner: OwnerDTO(login: "u", avatarURL: "https://example.com/a.png"),
            description: nil,
            htmlURL: ""
        )
        XCTAssertThrowsError(try SearchResultMapper.map(dto)) { error in
            XCTAssertEqual(error as? NetworkError, .decoding)
        }
    }

    // MARK: - SearchResult

    func test_searchResult_totalCount_items_매핑() throws {
        let dto = SearchResultDTO(totalCount: 42, items: [repoFixture(id: 1), repoFixture(id: 2)])
        let result = try SearchResultMapper.map(dto, page: 1)
        XCTAssertEqual(result.totalCount, 42)
        XCTAssertEqual(result.repositories.map(\.id), [1, 2])
        XCTAssertEqual(result.page, 1)
    }

    func test_searchResult_hasNextPage_items가_perPage와_같으면_true() throws {
        let items = (0..<SearchResultMapper.perPage).map { repoFixture(id: $0) }
        let dto = SearchResultDTO(totalCount: 1_000, items: items)
        let result = try SearchResultMapper.map(dto, page: 1)
        XCTAssertTrue(result.hasNextPage)
    }

    func test_searchResult_hasNextPage_items가_perPage보다_적으면_false() throws {
        let items = (0..<10).map { repoFixture(id: $0) }
        let dto = SearchResultDTO(totalCount: 10, items: items)
        let result = try SearchResultMapper.map(dto, page: 1)
        XCTAssertFalse(result.hasNextPage)
    }

    func test_searchResult_page는_파라미터_그대로_사용() throws {
        let dto = SearchResultDTO(totalCount: 0, items: [])
        let result = try SearchResultMapper.map(dto, page: 7)
        XCTAssertEqual(result.page, 7)
    }

    // MARK: - Decoding (JSON → DTO)

    func test_searchResultDTO_GitHub_응답_JSON_디코딩() throws {
        let json = """
        {
            "total_count": 2,
            "items": [
                {
                    "id": 1,
                    "name": "swift",
                    "full_name": "apple/swift",
                    "owner": {
                        "login": "apple",
                        "avatar_url": "https://avatars.githubusercontent.com/u/10639145"
                    },
                    "description": "The Swift Programming Language",
                    "html_url": "https://github.com/apple/swift"
                },
                {
                    "id": 2,
                    "name": "vapor",
                    "full_name": "vapor/vapor",
                    "owner": {
                        "login": "vapor",
                        "avatar_url": "https://avatars.githubusercontent.com/u/17364220"
                    },
                    "description": null,
                    "html_url": "https://github.com/vapor/vapor"
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let dto = try JSONDecoder().decode(SearchResultDTO.self, from: data)
        let result = try SearchResultMapper.map(dto, page: 1)

        XCTAssertEqual(result.totalCount, 2)
        XCTAssertEqual(result.repositories.count, 2)
        XCTAssertEqual(result.repositories[0].fullName, "apple/swift")
        XCTAssertNil(result.repositories[1].description)
    }

    // MARK: - Fixtures

    private func repoFixture(id: Int) -> RepositoryDTO {
        RepositoryDTO(
            id: id,
            name: "n\(id)",
            fullName: "u/n\(id)",
            owner: OwnerDTO(login: "u", avatarURL: "https://example.com/a.png"),
            description: nil,
            htmlURL: "https://github.com/u/n\(id)"
        )
    }
}
