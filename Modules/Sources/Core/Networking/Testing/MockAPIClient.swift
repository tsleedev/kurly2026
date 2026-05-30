import Foundation
import NetworkingInterface

/// 테스트용 APIClientProtocol Mock 구현체
///
/// result 또는 throw 동작을 주입하여 네트워크 레이어를 격리한다.
/// NSLock을 통해 thread-safe하게 구현된다.
public final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    // MARK: - Private

    private let lock = NSLock()
    private var _result: Any?
    private var _error: Error?
    private var _capturedEndpoints: [Endpoint] = []

    // MARK: - Init

    public init() {}

    // MARK: - Public

    /// 성공 응답을 주입한다.
    public func stub<T: Decodable & Sendable>(result: T) {
        lock.withLock {
            _result = result
            _error = nil
        }
    }

    /// 에러 응답을 주입한다.
    public func stubError(_ error: Error) {
        lock.withLock {
            _error = error
            _result = nil
        }
    }

    /// 호출된 Endpoint 목록을 반환한다.
    public var capturedEndpoints: [Endpoint] {
        lock.withLock { _capturedEndpoints }
    }

    // MARK: - APIClientProtocol

    public func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        lock.withLock { _capturedEndpoints.append(endpoint) }

        let (result, error) = lock.withLock { (_result, _error) }

        if let error {
            throw error
        }

        guard let typedResult = result as? T else {
            throw NetworkError.decoding
        }

        return typedResult
    }
}
