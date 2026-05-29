import XCTest
import WebViewInterface
@testable import WebView

final class WebViewDestinationTests: XCTestCase {

    private static let placeholderURL = URL(string: "https://github.com/apple/swift") ?? URL(fileURLWithPath: "/")
    private static let placeholderURL2 = URL(string: "https://github.com/vapor/vapor") ?? URL(fileURLWithPath: "/")

    func test_같은_url과_title이면_equal() {
        let lhs = WebViewDestination(url: Self.placeholderURL, title: "swift")
        let rhs = WebViewDestination(url: Self.placeholderURL, title: "swift")

        XCTAssertEqual(lhs, rhs)
        XCTAssertEqual(lhs.hashValue, rhs.hashValue)
    }

    func test_url이_다르면_not_equal() {
        let lhs = WebViewDestination(url: Self.placeholderURL, title: "swift")
        let rhs = WebViewDestination(url: Self.placeholderURL2, title: "swift")

        XCTAssertNotEqual(lhs, rhs)
    }

    func test_title이_다르면_not_equal() {
        let lhs = WebViewDestination(url: Self.placeholderURL, title: "swift")
        let rhs = WebViewDestination(url: Self.placeholderURL, title: "kotlin")

        XCTAssertNotEqual(lhs, rhs)
    }

    func test_프로퍼티가_init_값을_그대로_노출한다() {
        let destination = WebViewDestination(url: Self.placeholderURL, title: "swift")

        XCTAssertEqual(destination.url, Self.placeholderURL)
        XCTAssertEqual(destination.title, "swift")
    }
}

#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI

/// RepositoryWebView 스모크 테스트.
///
/// 본격적인 렌더링/스냅샷 검증은 chore/snapshot-tests PR에서 다룬다.
final class RepositoryWebViewSmokeTests: XCTestCase {

    @MainActor
    func test_init_은_destination을_받고_body가_평가된다() {
        let destination = WebViewDestination(
            url: URL(string: "https://github.com/apple/swift") ?? URL(fileURLWithPath: "/"),
            title: "swift"
        )
        let view = RepositoryWebView(destination: destination)
        // 컴파일 + body 평가가 throw하지 않으면 통과 (실제 WKWebView 인스턴스화는 UI 테스트에서)
        _ = view.body
    }
}
#endif
