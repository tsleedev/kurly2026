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
    private static var defaultHandler: ((URLRequest) -> Result<(Data, HTTPURLResponse), Error>)?
    private static var perURLHandlers: [URL: (URLRequest) -> Result<(Data, HTTPURLResponse), Error>] = [:]

    // MARK: - Public API

    /// 모든 URL에 대해 동작하는 기본 스텁 핸들러를 등록한다.
    ///
    /// 단일 테스트 클래스에서 setUp/tearDown으로 `reset()`을 보장한다면 안전하다.
    /// 병렬 테스트나 동일 클래스 안에서 URL별 다른 응답이 필요할 때는
    /// `register(for:handler:)`로 격리한다.
    public static func register(handler: @escaping (URLRequest) -> Result<(Data, HTTPURLResponse), Error>) {
        lock.withLock {
            defaultHandler = handler
        }
    }

    /// 특정 URL에 대해서만 동작하는 스텁 핸들러를 등록한다.
    ///
    /// 등록된 URL과 정확히 일치하는 요청만 이 핸들러로 응답하고,
    /// 그 외 URL은 `defaultHandler`로 fallback한다. URL이 서로 다르면 키가 충돌하지 않아
    /// 병렬 테스트에서도 핸들러가 덮어써질 위험이 없다.
    public static func register(
        for url: URL,
        handler: @escaping (URLRequest) -> Result<(Data, HTTPURLResponse), Error>
    ) {
        lock.withLock {
            perURLHandlers[url] = handler
        }
    }

    /// 등록된 모든 핸들러를 제거한다. tearDown에서 호출해 다음 테스트로 누수되지 않도록 한다.
    public static func reset() {
        lock.withLock {
            defaultHandler = nil
            perURLHandlers.removeAll()
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
        let requestedURL = request.url
        let resolved = URLProtocolStub.lock.withLock { () -> ((URLRequest) -> Result<(Data, HTTPURLResponse), Error>)? in
            if let url = requestedURL, let perURL = URLProtocolStub.perURLHandlers[url] {
                return perURL
            }
            return URLProtocolStub.defaultHandler
        }

        guard let handler = resolved else {
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
