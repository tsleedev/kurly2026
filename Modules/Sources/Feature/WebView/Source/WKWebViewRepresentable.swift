#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import WebKit

/// SwiftUI에서 사용할 `WKWebView` wrapper.
///
/// - 첫 `makeUIView`에서 URL 로드. URL이 실제로 변경됐을 때만 reload (Coordinator의 `lastLoadedURL`로 추적)
/// - `progress`는 `estimatedProgress` KVO로 0.0~1.0 갱신
/// - `isLoading`은 `WKNavigationDelegate`로 로딩 시작/종료 추적
struct WKWebViewRepresentable: UIViewRepresentable {

    let url: URL
    @Binding var progress: Double
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        context.coordinator.observeProgress(of: webView)
        context.coordinator.markLoaded(url: url)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // `webView.url`은 redirect 중간 단계나 KVO 갱신 사이클에 따라 url과 다를 수 있어 비교 대상으로 부적절.
        // Coordinator가 "마지막으로 우리가 로드를 요청한 URL"을 별도로 추적해 destination 변화 시에만 reload.
        if context.coordinator.shouldReload(for: url) {
            context.coordinator.markLoaded(url: url)
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(progress: $progress, isLoading: $isLoading)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {

        @Binding var progress: Double
        @Binding var isLoading: Bool
        private var progressObservation: NSKeyValueObservation?
        private var lastLoadedURL: URL?

        init(progress: Binding<Double>, isLoading: Binding<Bool>) {
            self._progress = progress
            self._isLoading = isLoading
        }

        func observeProgress(of webView: WKWebView) {
            // self를 capture하지 않고 Binding만 capture — view tear-down 후 KVO 잔여 호출이
            // dead self를 건드릴 위험 없음. KVO는 main thread에서 fire하지만 안전을 위해 MainActor로 hop.
            // `$progress`가 Binding<Double>이고, 이를 로컬 상수에 받아 closure가 캡처한다.
            // (capture list에 `[progress]`를 쓰면 wrappedValue인 Double을 복사 캡처해 wrappedValue 할당이 안 됨)
            let progressBinding = $progress
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { _, change in
                guard let value = change.newValue else { return }
                Task { @MainActor in
                    progressBinding.wrappedValue = value
                }
            }
        }

        func markLoaded(url: URL) {
            lastLoadedURL = url
        }

        func shouldReload(for url: URL) -> Bool {
            lastLoadedURL != url
        }

        // MARK: WKNavigationDelegate

        // `WKNavigation?`를 쓰는 이유: framework는 `WKNavigation!`로 선언했지만,
        // IUO는 Optional의 sugar이므로 Optional로 매칭해도 protocol 충족.
        // SwiftLint `implicitly_unwrapped_optional` 룰 회피.
        // 메서드는 항상 main thread에서 호출되므로 @MainActor 명시 — Swift 6 strict concurrency 대비.
        @MainActor
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            isLoading = true
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            isLoading = false
        }

        @MainActor
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
            isLoading = false
        }

        @MainActor
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
            isLoading = false
        }
    }
}
#endif
