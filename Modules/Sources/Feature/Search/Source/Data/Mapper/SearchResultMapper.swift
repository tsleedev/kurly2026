import Foundation
import NetworkInterface
import SearchInterface

/// DTO → Domain Entity 변환.
///
/// per_page 고정 정책에 따라 `hasNextPage`는 `items.count == perPage`로 판단한다.
/// URL 필드(`html_url`, `avatar_url`) 파싱 실패는 `NetworkError.decoding`으로 전파한다.
enum SearchResultMapper {

    /// `/search/repositories`에서 사용하는 페이지 크기. plan.md / api.md 참조.
    static let perPage = 30

    static func map(_ dto: SearchResultDTO, page: Int) throws -> SearchResult {
        let repositories = try dto.items.map(map(_:))
        return SearchResult(
            totalCount: dto.totalCount,
            repositories: repositories,
            page: page,
            hasNextPage: dto.items.count == perPage
        )
    }

    static func map(_ dto: RepositoryDTO) throws -> Repository {
        guard let htmlURL = URL(string: dto.htmlURL) else {
            throw NetworkError.decoding
        }
        return Repository(
            id: dto.id,
            name: dto.name,
            fullName: dto.fullName,
            owner: try map(dto.owner),
            description: dto.description,
            htmlURL: htmlURL
        )
    }

    static func map(_ dto: OwnerDTO) throws -> Owner {
        guard let avatarURL = URL(string: dto.avatarURL) else {
            throw NetworkError.decoding
        }
        return Owner(login: dto.login, avatarURL: avatarURL)
    }
}
