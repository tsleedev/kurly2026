import Foundation
import NetworkInterface

/// URLSession 기반 APIClientProtocol 구현체
public final class URLSessionAPIClient: APIClientProtocol {

    // MARK: - Private

    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Init

    public init(session: URLSession = .shared, decoder: JSONDecoder = .init()) {
        self.session = session
        self.decoder = decoder
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
            let (data, response) = try await fetchData(for: urlRequest)

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

    /// macOS 10.15 이상에서 동작하도록 withCheckedThrowingContinuation으로 래핑
    private func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }

    private func isRateLimited(_ response: HTTPURLResponse) -> Bool {
        let remaining = response.allHeaderFields["X-RateLimit-Remaining"] as? String
        let isRateLimitExhausted = remaining == "0"
        let isRateLimitStatusCode = response.statusCode == 403 || response.statusCode == 429
        return isRateLimitExhausted && isRateLimitStatusCode
    }

    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.allHeaderFields["X-RateLimit-Reset"] as? String else {
            return nil
        }
        guard let resetTimestamp = TimeInterval(value) else {
            return nil
        }
        let retryAfter = resetTimestamp - Date().timeIntervalSince1970
        return retryAfter > 0 ? retryAfter : nil
    }
}
