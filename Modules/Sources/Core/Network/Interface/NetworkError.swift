import Foundation

/// 네트워크 레이어에서 발생하는 에러
public enum NetworkError: Error, Equatable, Sendable {
    case invalidURL
    case transport
    case statusCode(Int)
    case decoding
    case rateLimited(retryAfter: TimeInterval?)
}
