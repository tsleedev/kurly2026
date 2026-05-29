import Foundation

/// GitHub Search API `items[].owner` DTO.
struct OwnerDTO: Decodable, Sendable {
    let login: String
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}
