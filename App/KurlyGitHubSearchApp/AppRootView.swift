import SwiftUI
import ImageLoadingInterface
import Search
import SearchInterface
import WebView
import WebViewInterface

/// 앱 루트 View. NavigationStack을 들고 AppRouter의 path 변화에 따라 화면을 push/pop.
///
/// router와 root SearchViewModel은 Container가 소유 — AppRootView가 매 init마다 새로 만드는 비용 0.
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
            SearchView(viewModel: container.searchViewModel)
                .navigationDestination(for: AppRouter.Destination.self) { destination in
                    switch destination {
                    case .searchResult(let searchResult):
                        SearchResultDestinationView(
                            destination: searchResult,
                            container: container,
                            imageLoader: imageLoader
                        )
                    case .webView(let webViewDestination):
                        RepositoryWebView(destination: webViewDestination)
                    }
                }
        }
    }
}

/// SearchResult destination wrapper.
///
/// `@State`로 ViewModel을 보존해, navigationDestination closure가 여러 번 호출되어도 같은 인스턴스를
/// 유지한다(페이지네이션/스크롤 위치 유실 방지). View의 `init`은 cheap이지만 `@State` 초기값은 view identity별로 1회만 평가됨.
private struct SearchResultDestinationView: View {

    @State private var viewModel: SearchResultViewModel
    private let imageLoader: any ImageLoaderProtocol

    init(
        destination: SearchResultDestination,
        container: AppDIContainer,
        imageLoader: any ImageLoaderProtocol
    ) {
        self.imageLoader = imageLoader
        self._viewModel = State(initialValue: container.makeSearchResultViewModel(destination: destination))
    }

    var body: some View {
        SearchResultView(viewModel: viewModel, imageLoader: imageLoader)
    }
}
