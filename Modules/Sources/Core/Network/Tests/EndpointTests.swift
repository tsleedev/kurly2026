import XCTest
import NetworkInterface

final class EndpointTests: XCTestCase {

    // MARK: - Properties

    private let baseURL = URL(string: "https://api.github.com")!

    // MARK: - url 조립

    func test_url_path만_있을때_올바른_URL을_반환한다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "/search/repositories")
        XCTAssertEqual(endpoint.url?.absoluteString, "https://api.github.com/search/repositories")
    }

    func test_url_queryItems가_있을때_쿼리스트링을_포함한다() {
        let endpoint = Endpoint(
            baseURL: baseURL,
            path: "/search/repositories",
            queryItems: [
                URLQueryItem(name: "q", value: "swift"),
                URLQueryItem(name: "page", value: "1"),
            ]
        )
        guard let url = endpoint.url else {
            XCTFail("url이 nil이면 안 됩니다")
            return
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "q", value: "swift")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "page", value: "1")))
    }

    func test_url_queryItems가_nil이면_쿼리스트링이_없다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "/search/repositories", queryItems: nil)
        let url = endpoint.url
        XCTAssertNil(url?.query)
    }

    func test_url_queryItems가_빈배열이면_쿼리스트링이_없다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "/search/repositories", queryItems: [])
        let url = endpoint.url
        XCTAssertNil(url?.query)
    }

    func test_url_baseURL에_trailing_slash가_없어도_올바르게_조립된다() {
        let endpoint = Endpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/v1/items"
        )
        XCTAssertEqual(endpoint.url?.absoluteString, "https://api.example.com/v1/items")
    }

    func test_url_빈_path이면_baseURL_자체를_반환한다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "")
        XCTAssertNotNil(endpoint.url)
    }

    func test_url_host없는_URL이면_nil을_반환한다() {
        let noHostURL = URL(string: "https://")!
        let endpoint = Endpoint(baseURL: noHostURL, path: "")
        XCTAssertNil(endpoint.url)
    }

    // MARK: - 기본값

    func test_method_기본값은_get이다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        XCTAssertEqual(endpoint.method, .get)
    }

    func test_queryItems_기본값은_nil이다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        XCTAssertNil(endpoint.queryItems)
    }

    func test_headers_기본값은_nil이다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "/test")
        XCTAssertNil(endpoint.headers)
    }

    // MARK: - method 설정

    func test_method_post로_설정할_수_있다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "/test", method: .post)
        XCTAssertEqual(endpoint.method, .post)
    }

    func test_method_delete로_설정할_수_있다() {
        let endpoint = Endpoint(baseURL: baseURL, path: "/test", method: .delete)
        XCTAssertEqual(endpoint.method, .delete)
    }

    // MARK: - 특수문자 인코딩

    func test_url_queryItems_특수문자가_퍼센트_인코딩된다() {
        let endpoint = Endpoint(
            baseURL: baseURL,
            path: "/search/repositories",
            queryItems: [URLQueryItem(name: "q", value: "swift language:swift")]
        )
        XCTAssertNotNil(endpoint.url)
        XCTAssertTrue(
            endpoint.url?.absoluteString.contains("%20") == true ||
            endpoint.url?.absoluteString.contains("+") == true
        )
    }
}
