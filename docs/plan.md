# 컬리(Kurly) 사전과제 — GitHub 저장소 검색 iOS 앱 구현 계획

## Context

컬리 iOS 직무 1차 직무적합성 인터뷰 전 **사전과제**로, **GitHub 저장소 검색 iOS 앱**을 구현해 Public GitHub 레포로 제출한다.

**채용 공고 기반 평가 포인트**
- 자격요건: **SwiftUI 개발 경험**, **테스트 코드 작성**, REST API 연동
- 우대사항: **앱 아키텍처 설계 역량**, **생성형 AI 적극 활용**, **CI/CD(GitHub Actions)**

→ 평가에 유리하도록 다음 조합을 채택한다:
1. **SwiftUI** + iOS 17 신기능 (`@Observable`, `NavigationStack`)
2. **모듈러 + Clean Architecture** (microfeatures 5-target)
3. **테스트**: Domain / Data / ViewModel / Snapshot 모두 커버
4. **AI Assist 활용**을 README에 명시
5. **GitHub Actions**: Test + SwiftLint 워크플로

예시 화면 2장(`예시 1..png`, `예시 2..png`)을 시각 레퍼런스로 사용한다.

---

## 기술 스택 결정사항

| 항목 | 결정 | 비고 |
|---|---|---|
| UI 프레임워크 | **SwiftUI** | 자격요건 부합. iOS 17 신기능 활용 |
| 아키텍처 | **Modular + Clean Architecture (Vertical Slicing)** | Feature 단위 모듈 분리 |
| 모듈 구조 패턴 | **microfeatures 5-target** | Interface / Source / Testing / Tests / Example |
| 프로젝트 도구 | **SwiftPM only** | Tuist 미사용 (과제 규모 대비 오버킬) |
| 비동기 | **async / await + Task** | iOS 17+ 안정. debounce는 `Clock` 주입 + `clock.sleep(for:)`. 외부 IO/Storage/Repository 추상화는 모두 async. 구현은 actor 또는 final class wrapper로. |
| ViewModel | **`@Observable` 매크로** | SwiftUI 1급 시민. View가 자동 추적 |
| 화면 전환 | **Router 패턴 + NavigationStack** | `@Observable AppRouter` + path 바인딩 |
| WebView | **`UIViewRepresentable`로 `WKWebView` wrap** | SwiftUI 메인 + 필요한 곳만 UIKit bridge |
| 외부 라이브러리 (프로덕션) | **없음 (순수 Swift)** | 평가자 환경 셋업 부담 0 |
| 외부 라이브러리 (테스트) | **swift-snapshot-testing** | Pointfree, SwiftUI View Snapshot도 지원 |
| 최소 지원 버전 | **iOS 17.0+** | 컬리 앱 기준 |
| 의존성 주입 | **생성자 주입 + AppDIContainer 수동 조립** | App 모듈의 Composition Root |
| 최근 검색어 저장 | **UserDefaults + Codable** | `[(keyword, date)]` 직렬화 |
| 테스트 | **Domain + Data + ViewModel + UI(Snapshot)** | XCTest + swift-snapshot-testing |
| CI/CD | **GitHub Actions: Test + SwiftLint** | 우대사항 충족 |

### 외부 라이브러리 정책
- **프로덕션 0**: 평가자에게 본인 기초 역량(URLSession, NSCache, async/await) 어필 + 환경 셋업 부담 0
- **테스트 1개**: `swift-snapshot-testing` (Pointfree, SwiftUI View Snapshot 표준)
- **Lint 1개**: `SwiftLint` (CI에서 강제)
- 컬리 채용 담당자에게 라이브러리 사용 문의는 하지 않음 (위 정책으로 충분)

---

## microfeatures 5-target 패턴

각 모듈은 최대 5개 sub-target으로 분리한다. 필요한 것만 만들고, 불필요한 건 생략한다.

| Sub-target | 역할 | 의존 방향 |
|---|---|---|
| `Interface` | 외부에 노출할 protocol, Entity, Destination enum | 다른 Feature의 Interface에만 의존 |
| `Source` | 실제 구현체 (View, ViewModel, Repository 구현) | 자신의 Interface + 외부 Interface |
| `Testing` | Mock, Stub, TestDouble (다른 모듈 테스트에서 import) | 자신의 Interface |
| `Tests` | 단위 테스트 | Source + 자신/타 모듈 Testing |
| `Example` | 데모 앱 / Preview (선택적) | Source |

### 핵심 효과
- 다른 모듈은 `XxxInterface`에만 의존 → `Source` 변경해도 재컴파일 안 됨 (빌드 시간 단축)
- `Testing`을 분리해 Mock 재사용 + 의존성 사이클 자동 차단
- Interface가 곧 Public API 문서 역할

---

## 모듈 구조 (Vertical Slicing + microfeatures)

```
KurlyGitHubSearch/                       ← Git Repo Root
├── App/                                 ← iOS App Target (Xcode 프로젝트)
│   ├── KurlyGitHubSearchApp.xcodeproj
│   └── Sources/
│       ├── KurlyGitHubSearchApp.swift   ← @main, AppRouter 보유
│       ├── AppRootView.swift            ← NavigationStack + navigationDestination
│       └── DI/AppDIContainer.swift      ← Composition Root
│
├── Modules/                             ← SwiftPM Package
│   ├── Package.swift                    ← 모든 target 정의
│   └── Sources/
│       │
│       ├── Core/                        ← 공용 인프라 모듈 그룹
│       │   ├── Network/
│       │   │   ├── Interface/           ← target: NetworkInterface
│       │   │   │   ├── APIClientProtocol.swift
│       │   │   │   ├── Endpoint.swift
│       │   │   │   ├── HTTPMethod.swift
│       │   │   │   └── NetworkError.swift
│       │   │   ├── Source/              ← target: Network
│       │   │   │   └── URLSessionAPIClient.swift
│       │   │   ├── Testing/             ← target: NetworkTesting
│       │   │   │   ├── MockAPIClient.swift
│       │   │   │   └── URLProtocolStub.swift
│       │   │   └── Tests/               ← target: NetworkTests
│       │   │
│       │   ├── Storage/
│       │   │   ├── Interface/           ← target: StorageInterface
│       │   │   │   └── KeyValueStorageProtocol.swift
│       │   │   ├── Source/              ← target: Storage
│       │   │   │   └── UserDefaultsStorage.swift
│       │   │   ├── Testing/             ← target: StorageTesting
│       │   │   │   └── InMemoryStorage.swift
│       │   │   └── Tests/               ← target: StorageTests
│       │   │
│       │   └── ImageLoading/
│       │       ├── Interface/           ← target: ImageLoadingInterface
│       │       │   └── ImageLoaderProtocol.swift
│       │       ├── Source/              ← target: ImageLoading
│       │       │   ├── ImageLoader.swift            (NSCache + URLSession)
│       │       │   └── CachedAsyncImage.swift       (SwiftUI View)
│       │       ├── Testing/             ← target: ImageLoadingTesting
│       │       │   └── MockImageLoader.swift
│       │       └── Tests/               ← target: ImageLoadingTests
│       │
│       └── Feature/                     ← 비즈니스 화면 모듈 그룹
│           ├── Search/                  ← Feature 모듈 (microfeatures)
│           │   ├── Interface/           ← target: SearchInterface
│           │   │   ├── UseCases/
│           │   │   │   ├── SearchRepositoriesUseCase.swift   (protocol)
│           │   │   │   ├── RecentKeywordUseCase.swift        (protocol)
│           │   │   │   └── AutoCompleteUseCase.swift         (protocol)
│           │   │   ├── Entities/
│           │   │   │   ├── Repository.swift
│           │   │   │   ├── Owner.swift
│           │   │   │   ├── SearchResult.swift
│           │   │   │   └── RecentKeyword.swift
│           │   │   ├── Destinations/
│           │   │   │   └── SearchResultDestination.swift   (struct: query — AppRouter가 사용)
│           │   │   └── Repositories/
│           │   │       ├── GitHubRepositoryProtocol.swift
│           │   │       └── RecentKeywordRepositoryProtocol.swift
│           │   │
│           │   ├── Source/              ← target: Search
│           │   │   ├── Presentation/
│           │   │   │   ├── SearchView.swift              (SwiftUI View)
│           │   │   │   ├── SearchViewModel.swift         (@Observable)
│           │   │   │   ├── SearchResultView.swift        (SwiftUI View)
│           │   │   │   ├── SearchResultViewModel.swift   (@Observable)
│           │   │   │   └── Components/
│           │   │   │       ├── RecentKeywordRow.swift
│           │   │   │       ├── AutoCompleteRow.swift
│           │   │   │       └── RepositoryRow.swift
│           │   │   ├── Domain/
│           │   │   │   ├── SearchRepositoriesUseCaseImpl.swift
│           │   │   │   ├── RecentKeywordUseCaseImpl.swift
│           │   │   │   └── AutoCompleteUseCaseImpl.swift
│           │   │   └── Data/
│           │   │       ├── DTOs/ (RepositoryDTO, SearchResultDTO)
│           │   │       ├── Repositories/ (GitHubRepository, RecentKeywordRepository)
│           │   │       └── Mappers/ (RepositoryDTO+Mapping)
│           │   │
│           │   ├── Testing/             ← target: SearchTesting
│           │   │   ├── MockSearchRepositoriesUseCase.swift
│           │   │   ├── MockRecentKeywordUseCase.swift
│           │   │   └── MockAutoCompleteUseCase.swift
│           │   │
│           │   ├── Tests/               ← target: SearchTests
│           │   │   ├── Domain/   (UseCase 단위테스트)
│           │   │   ├── Data/     (Repository, Mapper 테스트)
│           │   │   ├── Presentation/ (ViewModel 테스트)
│           │   │   └── Snapshot/ (View 스냅샷)
│           │   │
│           │   └── (Example 생략 — SwiftUI #Preview로 대체)
│           │
│           └── WebView/                 ← Feature 모듈 (microfeatures)
│               ├── Interface/           ← target: WebViewInterface
│               │   └── WebViewDestination.swift   (struct: url, title — AppRouter가 사용)
│               ├── Source/              ← target: WebView
│               │   ├── RepositoryWebView.swift          (SwiftUI View, init(destination:))
│               │   └── WKWebViewRepresentable.swift     (UIViewRepresentable)
│               ├── Testing/             ← target: WebViewTesting (필요 시)
│               └── Tests/               ← target: WebViewTests
│
├── .github/
│   └── workflows/
│       ├── test.yml                     ← GitHub Actions: swift test + xcodebuild test
│       └── lint.yml                     ← SwiftLint
├── .swiftlint.yml
└── README.md
```

### 의존성 그래프

```
App
 ├── AppRouter (모든 Destination 통합)
 ├── SearchInterface, Search
 ├── WebViewInterface, WebView
 ├── NetworkInterface, Network
 ├── StorageInterface, Storage
 └── ImageLoadingInterface, ImageLoading

Search   ──► SearchInterface
         ──► NetworkInterface, StorageInterface, ImageLoadingInterface
         ──► (WebView는 직접 의존 X — App이 Router로 연결)

Domain Layer 원칙:
  - Interface 모듈은 Foundation만 import (UIKit/SwiftUI/외부 0)
  - Source 내부의 Domain 폴더도 UIKit/SwiftUI import 안 함
  - Presentation 폴더만 SwiftUI import 허용
```

### Package.swift 구조 (요약)

```swift
let package = Package(
    name: "Modules",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SearchInterface", targets: ["SearchInterface"]),
        .library(name: "Search", targets: ["Search"]),
        .library(name: "SearchTesting", targets: ["SearchTesting"]),
        // WebView, Network, Storage, ImageLoading 동일 패턴
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing",
                 from: "1.15.0"),
    ],
    targets: [
        // === Feature/Search ===
        .target(name: "SearchInterface", path: "Sources/Feature/Search/Interface"),
        .target(name: "Search",
                dependencies: ["SearchInterface",
                               "NetworkInterface", "StorageInterface",
                               "ImageLoadingInterface"],
                path: "Sources/Feature/Search/Source"),
        .target(name: "SearchTesting",
                dependencies: ["SearchInterface"],
                path: "Sources/Feature/Search/Testing"),
        .testTarget(name: "SearchTests",
                    dependencies: [
                        "Search", "SearchTesting",
                        "NetworkTesting", "StorageTesting", "ImageLoadingTesting",
                        .product(name: "SnapshotTesting",
                                 package: "swift-snapshot-testing")
                    ],
                    path: "Sources/Feature/Search/Tests"),
        // === Feature/WebView, Core/Network, Core/Storage, Core/ImageLoading (동일 패턴) ===
    ]
)
```

---

## 핵심 컴포넌트 명세

### SearchInterface (Pure Swift, Foundation only)

```swift
public struct Repository: Equatable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let owner: Owner
    public let description: String?
    public let htmlURL: URL
}

public struct Owner: Equatable, Hashable {
    public let login: String
    public let avatarURL: URL
}

public struct SearchResult: Equatable {
    public let totalCount: Int
    public let repositories: [Repository]
    public let page: Int
    public let hasNextPage: Bool
}

public struct RecentKeyword: Equatable, Codable, Hashable {
    public let keyword: String
    public let searchedAt: Date
}

public protocol SearchRepositoriesUseCase: Sendable {
    func execute(query: String, page: Int) async throws -> SearchResult
}

public protocol RecentKeywordRepositoryProtocol: Sendable {
    func all() async -> [RecentKeyword]
    func append(_ keyword: String, at date: Date) async
    func remove(_ keyword: String) async
    func removeAll() async
}

public protocol RecentKeywordUseCase: Sendable {
    func recent() async -> [RecentKeyword]
    func save(_ keyword: String) async
    func delete(_ keyword: String) async
    func deleteAll() async
}

public protocol AutoCompleteUseCase: Sendable {
    func suggestions(for prefix: String) async -> [RecentKeyword]
}

// Destinations — AppRouter가 navigationDestination 분기에 사용.
// Feature의 화면 파라미터를 한 곳에 모아 Router 시그니처를 안정화한다.
public struct SearchResultDestination: Hashable {
    public let query: String
    public init(query: String) { self.query = query }
}
```

### WebViewInterface (Pure Swift, Foundation only)

```swift
public struct WebViewDestination: Hashable {
    public let url: URL
    public let title: String
    public init(url: URL, title: String) {
        self.url = url
        self.title = title
    }
}
```

### ViewModel 패턴 (`@Observable` + SwiftUI)

```swift
import Observation

@Observable
@MainActor
final class SearchViewModel {
    enum State: Equatable {
        case recent([RecentKeyword])
        case autocomplete([RecentKeyword])
    }
    
    private(set) var state: State = .recent([])
    var query: String = ""    // SwiftUI .searchable 양방향 바인딩
    
    // Router 위임 (closure)
    var onRequestSearch: ((String) -> Void)?
    var onRequestWebView: ((Repository) -> Void)?
    
    private let recentKeywordUseCase: RecentKeywordUseCase
    private let autoCompleteUseCase: AutoCompleteUseCase
    private let clock: any Clock<Duration>          // 테스트 시 TestClock 주입
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    
    init(recentKeywordUseCase: RecentKeywordUseCase,
         autoCompleteUseCase: AutoCompleteUseCase,
         clock: any Clock<Duration> = ContinuousClock()) { ... }
    
    func onAppear() { state = .recent(recentKeywordUseCase.recent()) }
    
    func onQueryChanged(_ newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await self.clock.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self.state = newValue.isEmpty
                ? .recent(self.recentKeywordUseCase.recent())
                : .autocomplete(self.autoCompleteUseCase.suggestions(for: newValue))
        }
    }
    
    func onSubmit() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        recentKeywordUseCase.save(query)
        onRequestSearch?(query)
    }
    
    func onTapRecent(_ keyword: String) {
        query = keyword
        recentKeywordUseCase.save(keyword)
        onRequestSearch?(keyword)
    }
    
    func onConfirmDelete(_ keyword: String) {
        recentKeywordUseCase.delete(keyword)
        state = .recent(recentKeywordUseCase.recent())
    }
    
    func onConfirmDeleteAll() {
        recentKeywordUseCase.deleteAll()
        state = .recent([])
    }
}
```

### Router 패턴 (SwiftUI NavigationStack)

```swift
// App/AppRouter.swift
//
// Destination은 각 Feature의 Interface에서 정의한 struct를 그대로 들고 다닌다.
// 이렇게 하면 화면별 파라미터가 늘어나도 AppRouter 시그니처가 바뀌지 않고,
// "WebViewDestination" 같은 타입이 실제로 의미를 가진다.
@Observable
@MainActor
final class AppRouter {
    enum Destination: Hashable {
        case searchResult(SearchResultDestination)
        case webView(WebViewDestination)
    }
    
    var path: [Destination] = []
    
    func showSearchResult(_ destination: SearchResultDestination) {
        path.append(.searchResult(destination))
    }
    func showWebView(_ destination: WebViewDestination) {
        path.append(.webView(destination))
    }
    func pop() { _ = path.popLast() }
    func popToRoot() { path.removeAll() }
}

// App/AppRootView.swift
struct AppRootView: View {
    @State private var router: AppRouter
    let container: AppDIContainer
    
    init(container: AppDIContainer) {
        self.container = container
        self._router = State(initialValue: AppRouter())
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            SearchView(viewModel: container.makeSearchViewModel(router: router))
                .navigationDestination(for: AppRouter.Destination.self) { dest in
                    switch dest {
                    case .searchResult(let destination):
                        SearchResultView(
                            viewModel: container.makeSearchResultViewModel(
                                destination: destination, router: router
                            )
                        )
                    case .webView(let destination):
                        RepositoryWebView(destination: destination)
                    }
                }
        }
    }
}

// AppDIContainer가 ViewModel 만들면서 Router를 closure로 주입
extension AppDIContainer {
    func makeSearchViewModel(router: AppRouter) -> SearchViewModel {
        let vm = SearchViewModel(
            recentKeywordUseCase: ...,
            autoCompleteUseCase: ...
        )
        vm.onRequestSearch = { [weak router] query in
            router?.showSearchResult(.init(query: query))
        }
        return vm
    }
}
```

> **이 구조에서 Search 모듈은 WebView 모듈을 직접 import 하지 않는다.** Router(=App)가 화면 흐름을 통합한다 → 모듈 간 결합 0.

### SwiftUI View (SearchView 골격)

```swift
struct SearchView: View {
    @State var viewModel: SearchViewModel
    @State private var deleteTarget: RecentKeyword?
    @State private var showDeleteAllAlert = false
    
    var body: some View {
        ContentList()
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "저장소 검색")
            .onChange(of: viewModel.query) { _, new in viewModel.onQueryChanged(new) }
            .onSubmit(of: .search) { viewModel.onSubmit() }
            .onAppear { viewModel.onAppear() }
            .alert("삭제하시겠습니까?", isPresented: .constant(deleteTarget != nil)) {
                Button("취소", role: .cancel) { deleteTarget = nil }
                Button("삭제", role: .destructive) {
                    if let k = deleteTarget { viewModel.onConfirmDelete(k.keyword) }
                    deleteTarget = nil
                }
            } message: {
                Text("'\(deleteTarget?.keyword ?? "")' 검색어를 삭제합니다.")
            }
            .alert("전체 삭제하시겠습니까?", isPresented: $showDeleteAllAlert) {
                Button("취소", role: .cancel) {}
                Button("전체 삭제", role: .destructive) { viewModel.onConfirmDeleteAll() }
            }
    }
    
    @ViewBuilder
    private func ContentList() -> some View {
        switch viewModel.state {
        case .recent(let items): RecentSection(items: items)
        case .autocomplete(let items): AutoCompleteSection(items: items)
        }
    }
}
```

### Core/Network

```swift
// NetworkInterface
public protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}
public struct Endpoint { let path: String; let method: HTTPMethod; ... }
public enum NetworkError: Error, Equatable {
    case invalidURL, transport, statusCode(Int),
         decoding, rateLimited(retryAfter: TimeInterval?)
}

// Network (Source)
public final class URLSessionAPIClient: APIClientProtocol { ... }
```

### Core/ImageLoading

```swift
// ImageLoaderProtocol (Interface)
public protocol ImageLoaderProtocol: Sendable {
    func image(for url: URL) async throws -> UIImage
    func cancel(for url: URL)
}

// ImageLoader (Source)
public actor ImageLoader: ImageLoaderProtocol {
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]
    public func image(for url: URL) async throws -> UIImage { ... }
}

// CachedAsyncImage (SwiftUI View)
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    let loader: ImageLoaderProtocol
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    
    public var body: some View {
        Group {
            if let image { content(Image(uiImage: image)) }
            else { placeholder() }
        }
        .task(id: url) {
            image = try? await loader.image(for: url)
        }
    }
}
```

---

## 화면 구성

### 1) SearchView (검색 입력 화면)
**레퍼런스**: `과제/예시 1..png`

- `.navigationTitle("Search")` (large title)
- `.searchable(text:, prompt: "저장소 검색")` modifier
- **상태 A (입력 없음)**: "최근 검색" 섹션 + chip 형태 + "전체삭제" 버튼
- **상태 B (입력 중)**: 자동완성 리스트 (prefix 매칭 **최근 검색어** + 검색 날짜)
  - 자동완성 소스는 로컬 최근 검색어만 사용. GitHub Search API에는 별도 suggest 엔드포인트가 없고, 매 키 입력마다 검색 API 호출은 rate limit(무인증 60req/h, 검색 API는 별도 10req/min) 부담
- `.onSubmit(of: .search)` → Router로 검색 결과 화면 push
- 최근 검색어 X 탭 → `.alert` (삭제 확인)
- 전체삭제 → `.alert` (전체 삭제 확인)

### 2) SearchResultView (검색 결과 화면)
**레퍼런스**: `과제/예시 2..png`

- `.navigationTitle(query)`로 표시 (결과 화면에서 `.searchable`은 사용하지 않음 — 재검색은 백 후 검색 화면에서)
- "266,714개 저장소" 형태 총 개수 헤더
- `List` + `RepositoryRow`
  - 좌측: `CachedAsyncImage` 썸네일 (40~48pt clip to circle)
  - 중앙: name (title), owner.login (description)
- **무한 스크롤**: 셀의 `.onAppear { Task { await viewModel.loadNextPageIfNeeded(currentItem: item) } }`
- 하단 로딩 인디케이터 (ProgressView)
- 셀 탭 → Router로 WebView push

### 3) RepositoryWebView
- `WKWebViewRepresentable`로 `repository.htmlURL` 로드
- `.navigationTitle(title)`
- 좌상단 < 백버튼 (자동), 우상단 새로고침 toolbar
- 로딩 진행률 (`ProgressView`, WKNavigationDelegate에서 estimatedProgress)

---

## 주요 데이터 흐름

### A. 검색 입력 → 자동완성
```
[입력 "swif"]
   │ .onChange(of: query) → viewModel.onQueryChanged
   │ debounce 300ms (Task + Task.sleep)
   ▼
AutoCompleteUseCase.suggestions(for: "swif")
   │ UserDefaults에서 RecentKeyword 전체 조회
   │ → keyword.lowercased().hasPrefix("swif") 필터
   │ → searchedAt desc, 상한 N개
   ▼
state = .autocomplete([...])
   ▼
[SwiftUI] @Observable 자동 추적으로 List 갱신
```

### B. 검색 실행 → 결과 화면
```
[.onSubmit(of: .search) / 최근 chip 탭 / 자동완성 탭]
   ▼
viewModel.onSubmit() or onTapRecent / onTapAutoComplete
   │ ① RecentKeywordUseCase.save("Swift")
   │ ② onRequestSearch?("Swift")
   ▼
AppRouter.showSearchResult(query: "Swift")
   │ path.append(.searchResult(query: "Swift"))
   ▼
NavigationStack이 자동으로 navigationDestination 매칭
   ▼
SearchResultView 렌더 + viewModel.loadFirstPage()
   │ SearchRepositoriesUseCase.execute(query, page: 1)
   ▼
items = [30개]; totalCount = 266714; hasNextPage = true
```

### C. 무한 스크롤
```
[RepositoryRow.onAppear, item == 마지막 ~5번째]
   ▼
viewModel.loadNextPageIfNeeded(currentItem: item)
   │ guard !isLoading, hasNextPage else { return }
   │ page += 1
   │ SearchRepositoriesUseCase.execute(query, page)
   ▼
items.append(contentsOf: newItems)
   │ hasNextPage = items.count < totalCount
   ▼
[SwiftUI] 자동 갱신
```

### D. 최근 검색어 삭제
```
[X 버튼 탭] → deleteTarget = keyword
   ▼
.alert("'Swift'를 삭제하시겠습니까?", ...)
   ▼ [삭제]
viewModel.onConfirmDelete("Swift")
   │ recentKeywordUseCase.delete → UserDefaults 갱신
   ▼
state = .recent(updated)
   ▼
[SwiftUI] List 자동 갱신
```

---

## API 명세

```
GET https://api.github.com/search/repositories?q={keyword}&page={page}&per_page=30

Headers:
  Accept: application/vnd.github+json
  X-GitHub-Api-Version: 2022-11-28

Response 매핑:
  total_count → SearchResult.totalCount
  items[]    → [RepositoryDTO] → [Repository]
    owner.avatar_url → Owner.avatarURL
    name             → Repository.name
    owner.login      → (UI에서 description으로 노출)
    html_url         → Repository.htmlURL

에러 매핑:
  401/403 + X-RateLimit-Remaining: 0 → NetworkError.rateLimited(retryAfter:)
  4xx/5xx → NetworkError.statusCode
  decode 실패 → NetworkError.decoding
```

---

## 테스트 전략

### Domain 테스트 (SearchTests/Domain/)
- `SearchRepositoriesUseCaseTests`: Mock Repository 주입, 정상/실패/빈결과
- `RecentKeywordUseCaseTests`: 추가 → 중복 → 삭제 → 전체삭제 시나리오
- `AutoCompleteUseCaseTests`: prefix 매칭 / 대소문자 무시 / 최신순 / 상한

### Data 테스트 (SearchTests/Data/)
- `GitHubRepositoryTests`: `URLProtocolStub`로 응답 주입, 매핑 검증, 에러 매핑
- `RecentKeywordRepositoryTests`: `InMemoryStorage`로 격리
- `MapperTests`: DTO → Entity 변환

### Presentation 테스트 (SearchTests/Presentation/)
- `SearchViewModelTests`: Mock UseCase 주입, 상태 전환
- **debounce 테스트**: `TestClock`(직접 구현, 외부 라이브러리 0 정책) 주입 → 가상 시간 advance로 결정론적 테스트
- `SearchResultViewModelTests`: 무한 스크롤 진입 조건, 페이지 누적, 종결
- Router 연결: `vm.onRequestSearch = { received.append($0) }` 검증

### Snapshot 테스트 (SearchTests/Snapshot/)
- `SearchViewSnapshotTests`: 최근 0개 / N개 / 자동완성 상태
- `SearchResultViewSnapshotTests`: 로딩 / 결과 N개 / 빈 결과 / 에러
- SwiftUI View → `assertSnapshot(of: view.frame(width:height:), as: .image)`

### Network 테스트 (NetworkTests/)
- URLProtocolStub 기반 통합 테스트
- 정상/타임아웃/4xx/5xx/디코딩 실패 매트릭스

---

## CI/CD (GitHub Actions)

### `.github/workflows/test.yml`
```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: latest-stable }
      - name: SwiftPM Test
        run: cd Modules && swift test
      - name: Xcode Test (Snapshot 포함)
        run: |
          xcodebuild test \
            -project App/KurlyGitHubSearchApp.xcodeproj \
            -scheme KurlyGitHubSearchApp \
            -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

### `.github/workflows/lint.yml`
```yaml
name: Lint
on: [push, pull_request]
jobs:
  lint:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Install SwiftLint
        run: brew install swiftlint
      - name: Run SwiftLint
        run: swiftlint --strict
```

> **Gemini PR 자동 리뷰**: GitHub Actions로 동작 (워크플로 파일은 별도 관리되어 본 plan에서는 명세 생략. PR 생성 시 자동으로 리뷰 코멘트가 달림).

### `.swiftlint.yml`
- 기본 규칙 + 모듈러 코드에 맞는 customization
- `force_cast`, `force_try`, `force_unwrapping` 강제 fail
- `implicitly_unwrapped_optional` warning
- 파일 길이 제한, 함수 길이 제한 등

---

## 개발 워크플로우 (Branch + PR + Review)

### 브랜치 전략
- `main`: 보호 브랜치. PR을 통해서만 머지. push 직접 금지
- `infra/*`: 인프라/뼈대 작업 (Package.swift, CI, CLAUDE.md 등)
- `feat/*`: 기능 단위 브랜치 (화면 단위 또는 모듈 단위)
- `chore/*`: 유지보수, 리팩토링, 테스트 보강

### 한 PR의 사이클
```
[로컬 작업 완료]
     ▼
[Claude Code 사전 리뷰]
   /code-review  또는  /code-review ultra (필요 시)
     ▼ (지적사항 반영)
[git push → PR 생성]
     ▼
[GitHub Actions 자동 실행]
   - test.yml (swift test + xcodebuild test)
   - lint.yml (SwiftLint --strict)
   - Gemini PR 자동 리뷰 (워크플로 별도 관리)
     ▼
[리뷰 코멘트 반영]
   - 수정 커밋을 PR 브랜치에 추가 push (squash 머지 시 단일 커밋으로 합쳐짐)
   - 각 인라인 코멘트에 답글로 "어떤 커밋에서 어떻게 반영했는지" 명시
     · 그대로 수용했는지 / 일부 변형했는지 / 거부했는지 + 근거
     · 거부 시: 트레이드오프 설명 + 회귀 테스트로 대체 가능 여부
   - CI 재실행 그린 확인 (test + lint 모두)
     ▼
[Self-merge → main]
   - Squash and merge로 단일 커밋 (리뷰 반영 히스토리는 PR 코멘트에 보존)
```

### 화면/모듈 단위 PR 분할

각 PR은 작고, 단일 책임을 가지며, 그 자체로 빌드/테스트 통과해야 한다.

| # | 브랜치 | 내용 | 의존 |
|---|---|---|---|
| 1 | `infra/skeleton` | Xcode 프로젝트, Package.swift 골격, .gitignore, README 뼈대, CLAUDE.md + docs/, SwiftLint 룰 | - |
| 2 | `infra/ci` | GitHub Actions: test.yml, lint.yml (Gemini 리뷰 워크플로는 별도 관리됨) | 1 |
| 3 | `feat/core-network` | NetworkInterface + URLSessionAPIClient + URLProtocolStub + Tests | 1 |
| 4 | `feat/core-storage` | StorageInterface + UserDefaultsStorage + InMemoryStorage + Tests | 1 |
| 5 | `feat/core-image-loading` | ImageLoader (actor + NSCache) + CachedAsyncImage + Tests | 1 |
| 6 | `feat/search-domain` | SearchInterface (Entity, UseCase protocol) + UseCase Impl + Mock + Tests | 1 |
| 7 | `chore/lint-pin-and-policy` | SwiftLint 0.63.2 false positive 회피 + Interface 분류 정책 추가 | 1 |
| 8 | `chore/network-polish` | URLSessionAPIClient `@unchecked Sendable` + URLProtocolStub URL별 핸들러 | 3 |
| 9 | `feat/search-domain` | Search 도메인 레이어 도입 (SearchInterface, UseCase Impl, Mock, Tests) | 1 |
| R | `refactor/async-actor-migration` | protocol async 통일 + actor 마이그레이션 + 문서 정리 (본 PR) | 9 |
| 10 | `feat/search-data` | DTO, Mapper, GitHubRepository, RecentKeywordRepository + Tests | 3, 4, 9 |
| 11 | `feat/search-screen` | SearchView + SearchViewModel + RecentKeyword/전체삭제 Alert + ViewModel Tests | 9, 10 |
| 12 | `feat/auto-complete` | 자동완성 debounce + 자동완성 상태 전환 + Tests | 11 |
| 13 | `feat/search-result-screen` | SearchResultView + ViewModel + List + 셀 + ViewModel Tests | 9, 10, 5 |
| 14 | `feat/infinite-scroll` | 무한 스크롤 트리거 + 페이지 누적 + Tests | 13 |
| 15 | `feat/webview` | WKWebViewRepresentable + RepositoryWebView + Tests | 1 |
| 16 | `feat/app-router-di` | AppDIContainer + AppRouter + AppRootView + NavigationStack 조립 (모든 화면 연결) | 11, 13, 15 |
| 17 | `chore/snapshot-tests` | SearchView / SearchResultView Snapshot 테스트 (record → commit) | 16 |
| 18 | `chore/readme-final` | README 최종 정리: 아키텍처 다이어그램, CI 배지, AI 활용 내역, 스크린샷. (각 PR이 자기 변경분은 README에 점진 반영하되, 이 PR에서 전체 톤/구조를 마무리) | 17 |

> 의존성이 있는 PR은 의존 PR이 머지된 후 작업 시작. 병렬 가능한 PR(3, 4, 5)은 동시 진행 가능.

### Gemini PR 자동 리뷰

GitHub Actions로 동작. 워크플로 파일은 별도 관리되어 본 plan에 명세하지 않음. PR 생성/업데이트 시 자동으로 코멘트가 달림.

### PR 전 Claude Code 사전 리뷰 체크리스트

PR 만들기 전에 로컬에서:
1. `git status` / `git diff` 로 변경 범위 확인
2. `swift test` 와 (필요 시) `xcodebuild test` 로 그린 확인
3. `swiftlint --strict` 통과 확인
4. Claude Code에서 `/code-review`  실행 → 지적사항 반영
5. 큰 PR이거나 위험도 있다고 판단되면 `/code-review ultra` 한 번 추가
6. 커밋 메시지 정리 (squash 또는 의미 있는 단위로 split)
7. `gh pr create` 또는 git push 후 GitHub 웹에서 PR 생성
8. PR 본문에 "어떤 변경 / 왜 / 테스트 방법" 작성

### PR 리뷰 응답 체크리스트 (Gemini 자동 리뷰 + 직접 코멘트)

리뷰가 올라온 뒤:
1. 모든 코멘트를 한 번에 훑어 **수용 / 일부 변형 / 거부**로 분류
2. 수용·변형 건: 적절한 단위의 커밋으로 반영하여 PR 브랜치에 push (별도 머지 X). 코멘트별로 분리하면 답글에 정확한 SHA를 매칭하기 용이
3. 인라인 코멘트에 답글 — **`@gemini-code-assist` 멘션 필수** (멘션 없으면 Gemini가 답글을 못 보고 재확인 못 함)
   - **신규 코멘트로 작성.** 기존 답글을 edit해 멘션을 끼워넣어도 webhook이 안 흔들려 Gemini가 호출되지 않음 (실측 확인).
   - 형식:
     ```
     @gemini-code-assist 리뷰 반영했습니다.

     **주제 타이틀 (severity)**

     - 변경: 무엇을
     - 근거: 왜 (특히 제안과 다른 선택을 했다면 그 이유)
     - 효과: 회귀 테스트 / 부산물

     Commit: <sha>
     ```
   - 분류 표기:
     - 수용: "제안대로 반영"
     - 변형: "변형 반영 — 이유: …"
     - 거부: "미반영 — 이유: …, 대안: …"
4. CI 재실행 확인 (test + lint 모두 그린)
5. 모든 코멘트 resolve 처리 (필요 시 reviewer 재요청)
6. Squash and merge로 단일 커밋 통합

---

## 단계별 구현 순서 (PR 매핑)

위 "화면/모듈 단위 PR 분할" 표 그대로의 순서로 진행한다. 각 PR이 곧 한 단계.

핵심 원칙:
- 각 PR은 빌드/테스트가 통과해야 한다 (CI green)
- 각 PR은 단일 책임이고 review-able한 크기로 유지
- 의존성 PR은 머지된 후 base 브랜치 rebase 후 작업
- 각 PR에 Claude Code 사전 리뷰 + Gemini 자동 리뷰가 모두 통과해야 머지

---

## 검증 (Verification)

### 빌드 / 실행
```bash
# 옵션 1: SwiftPM 단독 (모듈 빌드/테스트만)
cd Modules && swift build && swift test

# 옵션 2: 앱 실행 (Xcode)
open App/KurlyGitHubSearchApp.xcodeproj
# iOS 17 시뮬레이터로 Build & Run (⌘R)

# 옵션 3: xcodebuild로 전체 테스트
xcodebuild test \
  -project App/KurlyGitHubSearchApp.xcodeproj \
  -scheme KurlyGitHubSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'

# Lint
swiftlint --strict
```

### 시뮬레이터 수동 테스트 체크리스트
- [ ] 첫 실행 시 빈 "Search" 화면 (최근 검색어 0개)
- [ ] "swift" 입력 후 키보드 search → 결과 리스트 + 총 개수 표시
- [ ] 결과 셀 탭 → WebView로 저장소 페이지 로드
- [ ] 백 제스처 → 검색 화면, "swift"가 최근 검색어에 표시
- [ ] 최근 검색어 X 탭 → 확인 Alert → 정상 삭제
- [ ] "전체삭제" → 확인 Alert → 모두 삭제
- [ ] "swif"까지 입력 → 자동완성 "Swift"가 날짜와 함께 표시
- [ ] 자동완성 셀 탭 → 검색 결과 즉시 표시
- [ ] 결과 스크롤 끝까지 → 다음 페이지 자동 로드, 누적
- [ ] 네트워크 끊고 검색 → 에러 표시 (rate limit 케이스도 안내)
- [ ] 빠른 입력 debounce 동작 (Console 로그)
- [ ] 이미지 캐시 (재진입 시 깜빡임 X)
- [ ] WebView 로딩 진행률, 뒤로가기 정상

### 제출 전 최종 확인
- [ ] GitHub 레포 Public 설정
- [ ] README: 아키텍처 다이어그램 + 모듈 의존성 + 실행 방법 + 의사결정 근거 + AI 활용 내역 + CI 배지
- [ ] `swift test` / `xcodebuild test` 통과 (CI 그린)
- [ ] `swiftlint --strict` 통과
- [ ] 시뮬레이터 실행 1회 더 검증
- [ ] 링크 제출

---

## 프로젝트 정책 문서 구성 (CLAUDE.md + docs/)

Claude Code가 매 세션 자동 로드하는 `CLAUDE.md`를 인덱스로 두고, 상세 정책은 `docs/`로 분할한다.

```
KurlyGitHubSearch/
├── CLAUDE.md                    ← 짧은 인덱스, @docs/... 로 import
└── docs/
    ├── architecture.md          ← 모듈 구조, 의존성 규칙, microfeatures 5-target
    ├── coding-style.md          ← 명명 규칙, SwiftLint 룰, 파일 헤더, 주석
    ├── testing.md               ← 테스트 작성 가이드 (Domain/Data/VM/Snapshot)
    ├── api.md                   ← GitHub API 명세, 에러 매핑, rate limit 정책
    └── ai-usage.md              ← AI Assist 활용 내역 (제출 시 README에서 링크)
```

**`CLAUDE.md` (인덱스, ~3KB)**:
```markdown
# Kurly GitHub Search

## Project Context
컬리 iOS 사전과제 — GitHub 저장소 검색 앱.
SwiftUI + Modular Clean Architecture + microfeatures.

## Tech Stack
- iOS 17+, SwiftUI, @Observable, async/await
- SwiftPM (no Tuist), 순수 Swift (프로덕션 외부 라이브러리 0)
- 테스트: swift-snapshot-testing
- CI: GitHub Actions (test, lint)

## Policy Documents
@docs/architecture.md  - 모듈 구조, 의존성 규칙
@docs/coding-style.md  - 명명 규칙, SwiftLint
@docs/testing.md       - 테스트 작성 가이드
@docs/api.md           - GitHub API 명세
@docs/ai-usage.md      - AI 활용 내역

## Key Commands
- Build: `cd Modules && swift build`
- Test: `swift test`
- Lint: `swiftlint --strict`
```

**각 docs/ 파일 책임**:
- `architecture.md`: 모듈 의존성 그래프, "Domain은 무엇에도 의존 안 함" 같은 규칙
- `coding-style.md`: `final class` 기본, force unwrap 금지, MARK 주석 패턴
- `testing.md`: 새 기능 추가 시 어느 Layer에 어떤 테스트를 추가하는지
- `api.md`: GitHub Search API 엔드포인트, rate limit, DTO 매핑
- `ai-usage.md`: Claude/AI Assist를 어디서 어떻게 썼는지. **제출 시 README에서 링크 → 평가자가 읽음**

**`@docs/...` 문법**: Claude Code의 file import. 매 세션 자동 로드 X (CLAUDE.md만 자동), 필요 시 끌어옴 → CLAUDE.md는 가볍게 유지.

**docs/ai-usage.md의 이중 용도**:
1. Claude의 컨텍스트 입력 — 작업 일관성 유지
2. 평가자의 평가 자료 — 채용 공고 우대사항 "생성형 AI 적극 활용" 충족
   → 평가자가 한국어로 읽기 좋도록 구체적 활용 사례, 의사결정 흐름 정리

---

## 단계별 구현 순서에 CLAUDE.md/docs 추가

위 "단계별 구현 순서"의 1단계(레포 부트스트랩) 직후, **1.5단계로 CLAUDE.md + docs/ 골격 작성**을 추가한다. 이후 모든 작업이 일관된 정책 하에 진행됨.

---

## 별도 액션 아이템

1. **main 브랜치 보호 설정** (선택):
   - Settings → Branches → main → Require pull request, require status checks (test, lint)
2. **GitHub Public 설정 확인** (제출 시점)
3. **Gemini PR 자동 리뷰**: 별도 관리되는 워크플로가 정상 동작하는지 첫 PR에서 확인 (코멘트가 달리는지)

---

## 변경 로그

실제 머지된 PR 순서 (계획 외 추가/변경분 기록).

| PR | 브랜치 | 요약 |
|---|---|---|
| #7 | `chore/lint-pin-and-policy` | SwiftLint 0.63.2 false positive 회피 + Interface 분류 정책 추가 |
| #8 | `chore/network-polish` | URLSessionAPIClient `@unchecked Sendable` + URLProtocolStub URL별 핸들러 |
| #9 | `feat/search-domain` | Search 도메인 레이어 도입 (SearchInterface, UseCase Impl, Mock 5종, Tests) |
| (본 PR) | `refactor/async-actor-migration` | protocol async 통일 + actor 마이그레이션 + 문서 정리. PR #9 Gemini 리뷰 지적(Mock data race)의 근본 원인인 sync protocol 패턴을 제거하고 Storage·Search 전 영역을 async/actor로 통일. |
