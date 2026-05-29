import Foundation
import ImageLoading
import ImageLoadingInterface
import Network
import NetworkInterface
import Search
import SearchInterface
import Storage
import StorageInterface
import WebViewInterface

/// App의 Composition Root.
///
/// 외부 의존성(URLSession, UserDefaults 등)을 받아 ViewModel/Repository/UseCase 전체 그래프를 조립한다.
/// Singleton(`shared`) 금지 정책에 따라 App entry point가 1개 인스턴스를 만들어 AppRootView에 주입한다.
///
/// Router는 각 ViewModel 생성 시점에 closure로 주입한다 — ViewModel이 AppRouter 타입을 모르게.
///
/// `@MainActor`로 두는 이유: 비isolated `lazy var`는 thread-safe하지 않다(Swift는 lazy stored property에
/// 동기화를 보장하지 않음). 그래프 조립은 항상 main에서 수행되므로 isolation을 명시해 race를 차단한다.
@MainActor
final class AppDIContainer {

    // MARK: - Infrastructure (init에서 주입)

    private let apiClient: APIClientProtocol
    private let keyValueStorage: KeyValueStorageProtocol
    private let imageLoader: any ImageLoaderProtocol

    // MARK: - Derived (lazy, 한 번만 조립. @MainActor isolation으로 race 차단)

    private lazy var gitHubRepository: GitHubRepositoryProtocol = GitHubRepository(client: apiClient)
    private lazy var recentKeywordRepository: RecentKeywordRepositoryProtocol = RecentKeywordRepository(storage: keyValueStorage)

    private lazy var searchRepositoriesUseCase: SearchRepositoriesUseCase = SearchRepositoriesUseCaseImpl(repository: gitHubRepository)
    private lazy var recentKeywordUseCase: RecentKeywordUseCase = RecentKeywordUseCaseImpl(repository: recentKeywordRepository)
    private lazy var autoCompleteUseCase: AutoCompleteUseCase = AutoCompleteUseCaseImpl(repository: recentKeywordRepository)

    // MARK: - Init

    /// 기본 인자는 프로덕션 의존성. UI 테스트나 Example 앱에서 stubbed URLSession/UserDefaults를 주입할 수 있도록 인자화.
    init(
        apiClient: APIClientProtocol = URLSessionAPIClient(),
        keyValueStorage: KeyValueStorageProtocol = UserDefaultsStorage(defaults: .standard),
        imageLoader: any ImageLoaderProtocol = ImageLoader()
    ) {
        self.apiClient = apiClient
        self.keyValueStorage = keyValueStorage
        self.imageLoader = imageLoader
    }

    // MARK: - Public accessors

    func makeImageLoader() -> any ImageLoaderProtocol {
        imageLoader
    }

    // MARK: - ViewModel factories

    func makeSearchViewModel(router: AppRouter) -> SearchViewModel {
        let viewModel = SearchViewModel(
            recentKeywordUseCase: recentKeywordUseCase,
            autoCompleteUseCase: autoCompleteUseCase
        )
        // router는 App 수명과 같으므로 strong capture가 안전 + silent no-op 위험 제거.
        viewModel.onRequestSearch = { query in
            router.showSearchResult(SearchResultDestination(query: query))
        }
        return viewModel
    }

    func makeSearchResultViewModel(
        destination: SearchResultDestination,
        router: AppRouter
    ) -> SearchResultViewModel {
        let viewModel = SearchResultViewModel(
            query: destination.query,
            searchUseCase: searchRepositoriesUseCase
        )
        viewModel.onRequestWebView = { repository in
            router.showWebView(
                WebViewDestination(url: repository.htmlURL, title: repository.name)
            )
        }
        return viewModel
    }
}
