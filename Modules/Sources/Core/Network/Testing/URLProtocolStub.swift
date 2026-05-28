import Foundation

/// URLProtocol 기반 네트워크 스터빙 유틸리티
///
/// 테스트에서 URLSession 요청을 가로채 지정된 응답을 반환한다.
/// 사용 예:
/// ```swift
/// URLProtocolStub.register { _ in .success((data, response)) }
/// let session = URLSession(configuration: .stubbed)
/// ```
public final class URLProtocolStub: URLProtocol {

    // MARK: - Static State

    private static let lock = NSLock()
    private static var handler: ((URLRequest) -> Result<(Data, HTTPURLResponse), Error>)?

    // MARK: - Public API

    /// 스텁 핸들러를 등록한다.
    public static func register(handler: @escaping (URLRequest) -> Result<(Data, HTTPURLResponse), Error>) {
        lock.withLock {
            Self.handler = handler
        }
    }

    /// 등록된 핸들러를 제거한다.
    public static func reset() {
        lock.withLock {
            handler = nil
        }
    }

    // MARK: - URLProtocol

    override public static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override public static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        let currentHandler = URLProtocolStub.lock.withLock { URLProtocolStub.handler }

        guard let handler = currentHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        switch handler(request) {
        case let .success((data, response)):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override public func stopLoading() {}
}

// MARK: - URLSessionConfiguration Extension

public extension URLSessionConfiguration {
    /// URLProtocolStub이 적용된 URLSessionConfiguration
    static var stubbed: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return config
    }
}
