import Foundation

/// API 엔드포인트를 기술하는 값 타입
public struct Endpoint: Sendable {

    // MARK: - Properties

    public let baseURL: URL
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]?
    public let headers: [String: String]?

    // MARK: - Init

    public init(
        baseURL: URL,
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String]? = nil
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
    }

    // MARK: - Public

    /// URLComponents를 사용하여 최종 URL을 조립한다.
    /// scheme 또는 host가 없으면 nil을 반환한다.
    public var url: URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        let hasValidScheme = components?.scheme.map { !$0.isEmpty } ?? false
        let hasValidHost = components?.host.map { !$0.isEmpty } ?? false
        guard hasValidScheme, hasValidHost else {
            return nil
        }
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }
}
