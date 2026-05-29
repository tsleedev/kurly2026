import SwiftUI
import ImageLoadingInterface
import Search
import SearchInterface
import WebView
import WebViewInterface

/// 앱 루트 View. NavigationStack을 들고 AppRouter의 path 변화에 따라 화면을 push/pop.
///
/// ViewModel은 **@State로 보존**해 View body 재평가마다 새로 만들어지지 않도록 한다 — 검색어, 최근 검색,
/// 디바운스 상태 등이 부모 re-render 시 유실되는 버그를 방지.
struct AppRootView: View {

    @State private var router: AppRouter
    @State private var searchViewModel: SearchViewModel

    private let container: AppDIContainer
    private let imageLoader: any ImageLoaderProtocol

    init(container: AppDIContainer) {
        self.container = container
        self.imageLoader = container.makeImageLoader()
        let router = AppRouter()
        self._router = State(initialValue: router)
        self._searchViewModel = State(initialValue: container.makeSearchViewModel(router: router))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            SearchView(viewModel: searchViewModel)
                .navigationDestination(for: AppRouter.Destination.self) { destination in
                    switch destination {
                    case .searchResult(let searchResult):
                        SearchResultDestinationView(
                            destination: searchResult,
                            container: container,
                            router: router,
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
        router: AppRouter,
        imageLoader: any ImageLoaderProtocol
    ) {
        self.imageLoader = imageLoader
        self._viewModel = State(initialValue: container.makeSearchResultViewModel(
            destination: destination,
            router: router
        ))
    }

    var body: some View {
        SearchResultView(viewModel: viewModel, imageLoader: imageLoader)
    }
}
