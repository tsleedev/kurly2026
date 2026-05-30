import XCTest
import NetworkingInterface
import NetworkTesting
@testable import Network

final class URLSessionAPIClientTests: XCTestCase {

    // MARK: - Properties

    private var sut: URLSessionAPIClient?
    private let baseURL = URL(string: "https://api.github.com")!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
        let session = URLSession(configuration: .stubbed)
        sut = URLSessionAPIClient(session: session)
    }

    override func tearDown() {
        URLProtocolStub.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: - 정상 200 + Decoding

    func test_request_200응답이면_디코딩된_값을_반환한다() async throws {
        let client = try XCTUnwrap(sut)
        let expectedItem = SampleItem(id: 1, name: "swift")
        let data = try JSONEncoder().encode(expectedItem)
        let response = try makeHTTPResponse(statusCode: 200)
        URLProtocolStub.register { _ in .success((data, response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        let result: SampleItem = try await client.request(endpoint)

        XCTAssertEqual(result.id, expectedItem.id)
        XCTAssertEqual(result.name, expectedItem.name)
    }

    func test_request_201응답이면_디코딩된_값을_반환한다() async throws {
        let client = try XCTUnwrap(sut)
        let expectedItem = SampleItem(id: 2, name: "kurly")
        let data = try JSONEncoder().encode(expectedItem)
        let response = try makeHTTPResponse(statusCode: 201)
        URLProtocolStub.register { _ in .success((data, response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        let result: SampleItem = try await client.request(endpoint)

        XCTAssertEqual(result.id, 2)
    }

    // MARK: - Invalid URL

    func test_request_invalidURL이면_invalidURL_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        // scheme만 있고 host가 없는 URL은 Endpoint.url이 nil을 반환한다
        let invalidEndpoint = Endpoint(
            baseURL: URL(string: "https://")!,
            path: ""
        )

        do {
            let _: SampleItem = try await client.request(invalidEndpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    // MARK: - 4xx 에러

    func test_request_401응답이면_statusCode_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        let response = try makeHTTPResponse(statusCode: 401)
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .statusCode(401))
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    func test_request_404응답이면_statusCode_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        let response = try makeHTTPResponse(statusCode: 404)
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .statusCode(404))
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    // MARK: - 5xx 에러

    func test_request_500응답이면_statusCode_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        let response = try makeHTTPResponse(statusCode: 500)
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .statusCode(500))
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    func test_request_503응답이면_statusCode_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        let response = try makeHTTPResponse(statusCode: 503)
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .statusCode(503))
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    // MARK: - Rate Limit (403 + X-RateLimit-Remaining: 0)

    func test_request_403에_rateLimit헤더면_rateLimited_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        let response = try makeHTTPResponse(
            statusCode: 403,
            headers: [
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": "9999999999",
            ]
        )
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            if case .rateLimited = error {
                // 성공
            } else {
                XCTFail("rateLimited가 아닌 에러: \(error)")
            }
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    func test_request_429에_rateLimit헤더면_rateLimited_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        let response = try makeHTTPResponse(
            statusCode: 429,
            headers: [
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": "9999999999",
            ]
        )
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            if case .rateLimited = error {
                // 성공
            } else {
                XCTFail("rateLimited가 아닌 에러: \(error)")
            }
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    func test_request_403이지만_rateLimit헤더없으면_statusCode_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        let response = try makeHTTPResponse(statusCode: 403)
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .statusCode(403))
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    func test_request_429응답이면_헤더없어도_rateLimited_에러를_던진다() async throws {
        // 429는 X-RateLimit-Remaining 헤더와 무관하게 항상 rate limit
        URLProtocolStub.reset()
        let session = URLSession(configuration: .stubbed)
        let client = URLSessionAPIClient(session: session)
        let response = try makeHTTPResponse(statusCode: 429)
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            if case .rateLimited = error {
                // 성공
            } else {
                XCTFail("rateLimited가 아닌 에러: \(error)")
            }
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    // MARK: - Rate Limit retryAfter (now() 주입 deterministic 검증)

    func test_request_rateLimited_retryAfter_고정시간주입으로_deterministic하게_검증된다() async throws {
        // now = Unix 0 (1970-01-01), Reset = 3600 → retryAfter = 3600초
        let fixedNow = Date(timeIntervalSince1970: 0)
        URLProtocolStub.reset()
        let session = URLSession(configuration: .stubbed)
        let client = URLSessionAPIClient(session: session, now: { fixedNow })
        let response = try makeHTTPResponse(
            statusCode: 403,
            headers: [
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": "3600",
            ]
        )
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            if case .rateLimited(let retryAfter) = error {
                let unwrapped = try XCTUnwrap(retryAfter)
                XCTAssertEqual(unwrapped, 3600, accuracy: 0.001)
            } else {
                XCTFail("rateLimited가 아닌 에러: \(error)")
            }
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    func test_request_rateLimited_retryAfter_reset이_과거면_nil을_반환한다() async throws {
        // now = 7200, Reset = 3600 → retryAfter <= 0 → nil
        let fixedNow = Date(timeIntervalSince1970: 7200)
        URLProtocolStub.reset()
        let session = URLSession(configuration: .stubbed)
        let client = URLSessionAPIClient(session: session, now: { fixedNow })
        let response = try makeHTTPResponse(
            statusCode: 429,
            headers: [
                "X-RateLimit-Reset": "3600",
            ]
        )
        URLProtocolStub.register { _ in .success((Data(), response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            if case .rateLimited(let retryAfter) = error {
                XCTAssertNil(retryAfter, "reset이 과거이면 retryAfter는 nil이어야 합니다")
            } else {
                XCTFail("rateLimited가 아닌 에러: \(error)")
            }
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    // MARK: - Decoding 실패

    func test_request_잘못된_JSON이면_decoding_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        let invalidData = Data("not valid json".utf8)
        let response = try makeHTTPResponse(statusCode: 200)
        URLProtocolStub.register { _ in .success((invalidData, response)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .decoding)
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    // MARK: - Transport 에러

    func test_request_URLError이면_transport_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        URLProtocolStub.register { _ in .failure(URLError(.notConnectedToInternet)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .transport)
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    // MARK: - Headers 전달

    func test_request_headers가_URLRequest에_적용된다() async throws {
        let client = try XCTUnwrap(sut)
        var capturedRequest: URLRequest?
        let expectedItem = SampleItem(id: 1, name: "test")
        let data = try JSONEncoder().encode(expectedItem)
        let response = try makeHTTPResponse(statusCode: 200)

        URLProtocolStub.register { request in
            capturedRequest = request
            return .success((data, response))
        }

        let endpoint = Endpoint(
            baseURL: baseURL,
            path: "/test",
            headers: [
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            ]
        )
        let _: SampleItem = try await client.request(endpoint)

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "X-GitHub-Api-Version"), "2022-11-28")
    }

    // MARK: - Helpers

    private func makeHTTPResponse(
        statusCode: Int,
        headers: [String: String]? = nil
    ) throws -> HTTPURLResponse {
        let url = try XCTUnwrap(URL(string: "https://api.github.com/test"))
        return try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        ))
    }
}

// MARK: - Cancellation 에러

extension URLSessionAPIClientTests {

    func test_request_URLError_cancelled이면_cancelled_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        URLProtocolStub.register { _ in .failure(URLError(.cancelled)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        do {
            let _: SampleItem = try await client.request(endpoint)
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }

    func test_request_Task_취소시_cancelled_에러를_던진다() async throws {
        let client = try XCTUnwrap(sut)
        // URLProtocolStub이 URLError(.cancelled)를 던지도록 설정
        URLProtocolStub.register { _ in .failure(URLError(.cancelled)) }

        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        let task = Task<Void, Error> {
            let _: SampleItem = try await client.request(endpoint)
        }
        task.cancel()

        do {
            try await task.value
            XCTFail("에러를 던져야 합니다")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("NetworkError가 아닌 에러가 발생했습니다: \(error)")
        }
    }
}

// MARK: - Test Fixtures

private struct SampleItem: Codable, Sendable {
    let id: Int
    let name: String
}
