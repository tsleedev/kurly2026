import Foundation

/// GitHub Search API의 `/search/repositories` 응답 DTO.
struct SearchResultDTO: Decodable, Sendable {
    let totalCount: Int
    let items: [RepositoryDTO]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}
