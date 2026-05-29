import Foundation

/// AppRouter가 WebView 화면으로 push할 때 들고 다닐 식별값.
///
/// AppRouter는 Feature Source가 아닌 Interface의 Destination struct를 직접 보유한다.
public struct WebViewDestination: Hashable, Sendable {
    public let url: URL
    public let title: String

    public init(url: URL, title: String) {
        self.url = url
        self.title = title
    }
}
