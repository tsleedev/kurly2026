import Foundation

/// API 클라이언트 추상화 프로토콜
public protocol APIClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
}
