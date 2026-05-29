import Foundation

/// GitHub Search API `items[]` 요소 DTO.
struct RepositoryDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let owner: OwnerDTO
    let description: String?
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case owner
        case description
        case htmlURL = "html_url"
    }
}
