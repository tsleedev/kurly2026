import SwiftUI
import SearchInterface
import WebViewInterface

/// 앱 전체 화면 흐름을 관리하는 Router.
///
/// Destination은 각 Feature의 Interface에서 정의한 struct를 그대로 들고 다닌다.
/// 화면별 파라미터가 늘어나도 AppRouter 시그니처가 바뀌지 않고, "WebViewDestination" 같은 타입이
/// 실제로 의미를 가진다.
@MainActor
@Observable
public final class AppRouter {

    public enum Destination: Hashable {
        case searchResult(SearchResultDestination)
        case webView(WebViewDestination)
    }

    public var path: [Destination] = []

    public init() {}

    public func showSearchResult(_ destination: SearchResultDestination) {
        path.append(.searchResult(destination))
    }

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
