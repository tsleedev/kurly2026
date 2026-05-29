import SwiftUI
import WebViewInterface

/// 앱 전체 화면 흐름을 관리하는 Router.
///
/// 현재는 WebView push만 담당한다 — 검색 결과는 SearchView 내부 state로 표시되어
/// NavigationStack에 별도 destination을 추가하지 않는다(`refactor/search-result-inline-state`).
@MainActor
@Observable
public final class AppRouter {

    public enum Destination: Hashable {
        case webView(WebViewDestination)
    }

    public var path: [Destination] = []

    public init() {}

    public func showWebView(_ destination: WebViewDestination) {
        path.append(.webView(destination))
    }

    public func pop() {
        _ = path.popLast()
    }

    public func popToRoot() {
        path.removeAll()
    }
}
