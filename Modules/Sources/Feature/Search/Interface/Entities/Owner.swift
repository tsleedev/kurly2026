import Foundation

/// GitHub 저장소 소유자 정보.
public struct Owner: Equatable, Hashable, Sendable {
    public let login: String
    public let avatarURL: URL

    public init(login: String, avatarURL: URL) {
        self.login = login
        self.avatarURL = avatarURL
    }
}
