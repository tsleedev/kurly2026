#if canImport(UIKit)
import XCTest
import UIKit
@testable import ImageLoading
import ImageLoadingInterface
import ImageLoadingTesting

// MARK: - URLProtocol Stub

private final class StubURLProtocol: URLProtocol {

    struct Response {
        let data: Data
        let statusCode: Int
    }

    private static let lock = NSLock()
    private static var stubs: [URL: Response] = [:]
    private static var requestCounts: [URL: Int] = [:]

    static func stub(_ response: Response, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        stubs[url] = response
    }

    static func requestCount(for url: URL) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCounts[url] ?? 0
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        stubs = [:]
        requestCounts = [:]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        StubURLProtocol.lock.lock()
        StubURLProtocol.requestCounts[url, default: 0] += 1
        let stub = StubURLProtocol.stubs[url]
        StubURLProtocol.lock.unlock()

        guard let stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Helper

private func makeStubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

/// 1×1 PNG 픽셀 — UIImage(data:) 성공 보장
private let validImageData: Data = {
    let size = CGSize(width: 1, height: 1)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.pngData { _ in
        UIColor.red.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
    }
}()

// MARK: - Tests

final class ImageLoaderTests: XCTestCase {

    // URL(string:) 은 리터럴 상수라 nil 이 될 수 없음 — guard 패턴으로 force unwrap 회피
    private static let testURLString = "https://example.com/img.png"

    private func makeURL() throws -> URL {
        guard let url = URL(string: Self.testURLString) else {
            throw XCTSkip("테스트 URL 생성 실패 — 환경 이상")
        }
        return url
    }

    private func makeSUT() -> ImageLoader {
        ImageLoader(session: makeStubbedSession(), cache: NSCache())
    }

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Normal Load

    func test_image_정상응답이면_UIImage_반환() async throws {
        let url = try makeURL()
        StubURLProtocol.stub(.init(data: validImageData, statusCode: 200), for: url)
        let sut = makeSUT()

        let result = try await sut.image(for: url)

        XCTAssertNotNil(result)
    }

    // MARK: - Cache Hit

    func test_image_두번째_호출은_캐시에서_반환되어_stub_추가호출_없음() async throws {
        let url = try makeURL()
        StubURLProtocol.stub(.init(data: validImageData, statusCode: 200), for: url)
        let sut = makeSUT()

        _ = try await sut.image(for: url)
        let countAfterFirst = StubURLProtocol.requestCount(for: url)

        _ = try await sut.image(for: url)
        let countAfterSecond = StubURLProtocol.requestCount(for: url)

        XCTAssertEqual(countAfterFirst, 1)
        XCTAssertEqual(countAfterSecond, 1, "캐시 hit이므로 네트워크 요청이 추가되면 안 됨")
    }

    // MARK: - Concurrent Dedup

    func test_image_동시_요청_두개_stub_호출은_한번만() async throws {
        let url = try makeURL()
        StubURLProtocol.stub(.init(data: validImageData, statusCode: 200), for: url)
        let sut = makeSUT()

        async let first = sut.image(for: url)
        async let second = sut.image(for: url)

        let (img1, img2) = try await (first, second)

        XCTAssertNotNil(img1)
        XCTAssertNotNil(img2)
        XCTAssertLessThanOrEqual(
            StubURLProtocol.requestCount(for: url), 1,
            "in-flight dedup 으로 네트워크 요청이 최대 1회여야 함"
        )
    }

    // MARK: - Error: invalidResponse

    func test_image_HTTP404이면_invalidResponse_에러() async throws {
        let url = try makeURL()
        StubURLProtocol.stub(.init(data: Data(), statusCode: 404), for: url)
        let sut = makeSUT()

        do {
            _ = try await sut.image(for: url)
            XCTFail("에러가 발생해야 함")
        } catch let error as ImageLoadingError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - Error: decodingFailed

    func test_image_깨진데이터이면_decodingFailed_에러() async throws {
        let url = try makeURL()
        let brokenData = Data("not-an-image".utf8)
        StubURLProtocol.stub(.init(data: brokenData, statusCode: 200), for: url)
        let sut = makeSUT()

        do {
            _ = try await sut.image(for: url)
            XCTFail("에러가 발생해야 함")
        } catch let error as ImageLoadingError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("예상치 못한 에러: \(error)")
        }
    }
}
#endif
