import Foundation

public enum ImageLoadingError: Error, Equatable, Sendable {
    case invalidResponse
    case decodingFailed
    case cancelled
}
