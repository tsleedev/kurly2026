import Foundation
import NetworkInterface

/// URLSession 기반 APIClientProtocol 구현체
public final class URLSessionAPIClient: APIClientProtocol {

    // MARK: - Private

    private let session: URLSession
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date

    // MARK: - Init

    public init(
        session: URLSession = .shared,
        decoder: JSONDecoder = .init(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.decoder = decoder
        self.now = now
    }

    // MARK: - Public

    public func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method.rawValue
        endpoint.headers?.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let http = response as? HTTPURLResponse else {
                throw NetworkError.transport
            }

            if isRateLimited(http) {
                let retryAfter = parseRetryAfter(from: http)
                throw NetworkError.rateLimited(retryAfter: retryAfter)
            }

            guard (200..<300).contains(http.statusCode) else {
                throw NetworkError.statusCode(http.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decoding
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport
        }
    }

    // MARK: - Private

    /// 429는 항상 rate limit. 403은 X-RateLimit-Remaining == "0"일 때만 rate limit.
    private func isRateLimited(_ response: HTTPURLResponse) -> Bool {
        if response.statusCode == 429 { return true }
        if response.statusCode == 403 {
            return response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0"
        }
        return false
    }

    /// X-RateLimit-Reset Unix timestamp를 현재 시각과 비교해 대기 시간을 반환한다.
    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
              let resetTimestamp = TimeInterval(value) else { return nil }
        let retryAfter = resetTimestamp - now().timeIntervalSince1970
        return retryAfter > 0 ? retryAfter : nil
    }
}
