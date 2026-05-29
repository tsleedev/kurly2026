import Foundation
import SearchInterface

/// DTO → Domain Entity 변환.
///
/// 개별 아이템의 URL 파싱이 실패해도 해당 아이템만 건너뛰고 나머지 정상 아이템은 보존한다
/// (방어적 디코딩). 페이지 전체가 에러로 전환되어 UX가 깨지는 것을 막는다.
///
/// `hasNextPage`는 두 조건을 모두 만족할 때 true:
/// - 현재 페이지가 가득 차 있음 (`items.count == perPage`)
/// - 누적 아이템 수가 전체 개수보다 적음 (`page * perPage < totalCount`)
/// totalCount가 perPage 배수인 마지막 페이지에서의 불필요한 next-page 요청을 막는다.
enum SearchResultMapper {

    /// `/search/repositories`에서 사용하는 페이지 크기. plan.md / api.md 참조.
    static let perPage = 30

    static func map(_ dto: SearchResultDTO, page: Int) -> SearchResult {
        let repositories = dto.items.compactMap(map(_:))
        return SearchResult(
            totalCount: dto.totalCount,
            repositories: repositories,
            page: page,
            hasNextPage: dto.items.count == perPage && page * perPage < dto.totalCount
        )
    }

    static func map(_ dto: RepositoryDTO) -> Repository? {
        guard let owner = map(dto.owner),
              let htmlURL = URL(string: dto.htmlURL) else {
            return nil
        }
        return Repository(
            id: dto.id,
            name: dto.name,
            fullName: dto.fullName,
            owner: owner,
            description: dto.description,
            htmlURL: htmlURL
        )
    }

    static func map(_ dto: OwnerDTO) -> Owner? {
        guard let avatarURL = URL(string: dto.avatarURL) else {
            return nil
        }
        return Owner(login: dto.login, avatarURL: avatarURL)
    }
}
