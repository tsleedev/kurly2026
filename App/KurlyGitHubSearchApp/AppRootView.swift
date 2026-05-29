import SwiftUI
import ImageLoadingInterface
import Search
import WebView
import WebViewInterface

/// 앱 루트 View. NavigationStack을 들고 AppRouter의 path 변화에 따라 화면을 push/pop.
///
/// router와 root SearchViewModel은 Container가 소유 — AppRootView가 매 init마다 새로 만드는 비용 0.
/// 검색 결과는 SearchView 내부 state로 표시되므로 path에는 WebView destination만 들어간다.
struct AppRootView: View {

    private let container: AppDIContainer
    private let imageLoader: any ImageLoaderProtocol

    init(container: AppDIContainer) {
        self.container = container
        self.imageLoader = container.makeImageLoader()
    }

    var body: some View {
        @Bindable var router = container.router
        return NavigationStack(path: $router.path) {
            SearchView(viewModel: container.searchViewModel, imageLoader: imageLoader)
                .navigationDestination(for: AppRouter.Destination.self) { destination in
                    switch destination {
                    case .webView(let webViewDestination):
                        RepositoryWebView(destination: webViewDestination)
                    }
                }
        }
    }
}
