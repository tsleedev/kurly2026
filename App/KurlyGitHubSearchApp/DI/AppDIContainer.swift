import Foundation
import ImageLoading
import ImageLoadingInterface
import Networking
import NetworkingInterface
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
/// **App 수명과 같은 객체(`router`, `searchViewModel`)는 Container가 직접 소유**한다 — AppRootView가
/// 매 init마다 만들어 @State로 넘기는 패턴 대비 객체 생성/폐기 비용 0.
/// 결과 화면 진입 시마다 새로 만들어지는 SearchResultViewModel만 factory 메서드로 제공.
///
/// `@MainActor`로 두는 이유: 비isolated `lazy var`는 thread-safe하지 않다(Swift는 lazy stored property에
/// 동기화를 보장하지 않음). 그래프 조립은 항상 main에서 수행되므로 isolation을 명시해 race를 차단한다.
@MainActor
final class AppDIContainer {

    // MARK: - App-lifetime objects

    let router = AppRouter()

    // MARK: - Infrastructure (init에서 주입)

    private let apiClient: APIClientProtocol
    private let keyValueStorage: KeyValueStorageProtocol
    private let imageLoader: any ImageLoaderProtocol

    // MARK: - Derived (lazy, 한 번만 조립)

    private lazy var gitHubRepository: GitHubRepositoryProtocol = GitHubRepository(client: apiClient)
    private lazy var recentKeywordRepository: RecentKeywordRepositoryProtocol = RecentKeywordRepository(storage: keyValueStorage)

    private lazy var searchRepositoriesUseCase: SearchRepositoriesUseCase = SearchRepositoriesUseCaseImpl(repository: gitHubRepository)
    private lazy var recentKeywordUseCase: RecentKeywordUseCase = RecentKeywordUseCaseImpl(repository: recentKeywordRepository)
    private lazy var autoCompleteUseCase: AutoCompleteUseCase = AutoCompleteUseCaseImpl(repository: recentKeywordRepository)

    /// 검색 진입 화면 VM은 앱 수명과 같으므로 Container가 직접 소유 (lazy).
    /// 결과 VM은 submit/탭마다 새로 만들어지므로 factory closure를 주입 — SearchViewModel은
    /// `SearchRepositoriesUseCase` 의존성을 알 필요가 없다.
    ///
    /// `[unowned self]`: Container는 App entry point가 소유해 SearchViewModel(자식)보다 오래 산다.
    /// strong 캡쳐는 container → searchViewModel → closure → container 순환을 만든다.
    private(set) lazy var searchViewModel: SearchViewModel = SearchViewModel(
        recentKeywordUseCase: recentKeywordUseCase,
        autoCompleteUseCase: autoCompleteUseCase,
        makeSearchResultViewModel: { [unowned self] destination in
            self.makeSearchResultViewModel(destination: destination)
        }
    )

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

    /// destination별로 다른 ViewModel이므로 factory 유지. SearchViewModel이 closure로 호출.
    private func makeSearchResultViewModel(
        destination: SearchResultDestination
    ) -> SearchResultViewModel {
        let viewModel = SearchResultViewModel(
            query: destination.query,
            searchUseCase: searchRepositoriesUseCase
        )
        viewModel.onRequestWebView = { [router] repository in
            router.showWebView(
                WebViewDestination(url: repository.htmlURL, title: repository.name)
            )
        }
        return viewModel
    }
}
