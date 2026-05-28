import Foundation

/// GitHub 저장소 엔티티.
public struct Repository: Equatable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let owner: Owner
    public let description: String?
    public let htmlURL: URL

    public init(
        id: Int,
        name: String,
        fullName: String,
        owner: Owner,
        description: String?,
        htmlURL: URL
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.owner = owner
        self.description = description
        self.htmlURL = htmlURL
    }
}
