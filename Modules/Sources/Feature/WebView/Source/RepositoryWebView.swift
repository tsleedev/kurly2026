#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import WebViewInterface

/// 저장소 페이지를 WKWebView로 보여주는 화면.
///
/// AppRouter가 `WebViewDestination`을 들고 push하면 이 View가 url을 로드한다.
/// 상단에 로딩 진행률 프로그레스 바를 표시한다(로딩 중에만).
public struct RepositoryWebView: View {

    let destination: WebViewDestination

    @State private var progress: Double = 0
    @State private var isLoading: Bool = false

    public init(destination: WebViewDestination) {
        self.destination = destination
    }

    public var body: some View {
        WKWebViewRepresentable(
            url: destination.url,
            progress: $progress,
            isLoading: $isLoading
        )
        .overlay(alignment: .top) {
            // 로딩 중이거나 0<progress<1 인 구간만 표시. 끝나면 자연스럽게 사라짐
            if isLoading && progress < 1.0 {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
