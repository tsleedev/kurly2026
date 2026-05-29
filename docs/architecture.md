# Architecture

## 전체 구조 (Vertical Slicing + microfeatures)

```
kurly2026/
├── App/                                ← iOS App Target (Xcode 프로젝트)
│   └── KurlyGitHubSearchApp/           ← @main, AppRouter, AppDIContainer
├── Modules/                            ← SwiftPM Package
│   └── Sources/
│       ├── Core/                       ← 공용 인프라 모듈 그룹
│       │   ├── Network/{Interface,Source,Testing,Tests}/
│       │   ├── Storage/{Interface,Source,Testing,Tests}/
│       │   └── ImageLoading/{Interface,Source,Testing,Tests}/
│       └── Feature/                    ← 비즈니스 화면 모듈 그룹
│           ├── Search/{Interface,Source,Testing,Tests}/
│           └── WebView/{Interface,Source,Testing,Tests}/
└── docs/
```

## microfeatures 5-target 패턴

각 Feature 모듈은 다음 sub-target으로 분리한다. 필요한 것만 만든다.

| Sub-target | 역할 | 의존 방향 |
|---|---|---|
| `Interface` | 외부에 노출할 protocol, Entity, Destination | 다른 Feature의 Interface만 |
| `Source` | 실제 구현 (View, ViewModel, Repository 구현) | 자신의 Interface + 외부 Interface |
| `Testing` | Mock, Stub, TestDouble (다른 모듈 Tests에서 import) | 자신의 Interface |
| `Tests` | 단위/스냅샷 테스트 | Source + 자신/타 모듈 Testing |
| `Example` | 데모 앱 / Preview (선택적) | Source |

### 효과
- 다른 모듈은 `XxxInterface`에만 의존 → `Source` 변경해도 재컴파일 안 됨
- `Testing`을 분리해 Mock 재사용 + 의존성 사이클 차단
- `Interface`가 곧 Public API 문서

## 의존성 그래프

```
App
 ├── AppRouter (Destination = WebViewDestination)
 ├── SearchInterface,        Search
 ├── WebViewInterface,       WebView
 ├── NetworkInterface,       Network
 ├── StorageInterface,       Storage
 └── ImageLoadingInterface,  ImageLoading

Search   ──► SearchInterface
         ──► NetworkInterface, StorageInterface, ImageLoadingInterface
         ──► (WebView 직접 의존 X — App이 Router로 연결)

WebView  ──► WebViewInterface
```

## 레이어별 import 규칙

| 폴더 / 모듈 | 허용 import |
|---|---|
| `*Interface/` (도메인/플랫폼 독립) | Foundation only |
| `*Interface/` (OS-bound 인프라) | Foundation + 해당 OS 플랫폼 타입 (UIKit/SwiftUI) — [Interface 분류](#interface-분류) 참조 |
| `*/Domain/` (UseCase, Entity) | Foundation only |
| `*/Data/` (Repository, DTO) | Foundation + own Interface + 외부 Interface |
| `*/Presentation/` (View, ViewModel) | SwiftUI + own Interface + Domain |
| `App/` | 모든 모듈 (Composition Root) |

위반 사례:
- ❌ 도메인/플랫폼 독립 Interface에서 SwiftUI/UIKit import
- ❌ `Search`(Source)에서 `WebView` import (Router로만 연결)
- ❌ `Interface` → `Source` import (방향 역전)

### Interface 분류

`*Interface/` 모듈은 두 가지로 나뉜다:

- **도메인 및 플랫폼 독립 Interface** (Foundation only)
  - 비즈니스 도메인: `SearchInterface`, `WebViewInterface`
  - 공용 인프라(플랫폼 독립): `NetworkInterface`, `StorageInterface`
  - UIKit/SwiftUI/외부 라이브러리 import 금지
- **OS-bound 인프라 Interface** — 본질적으로 OS API 추상화인 경우
  - 예: `ImageLoadingInterface` (UIImage 노출)
  - 해당 플랫폼 타입(UIKit/SwiftUI) 노출 **허용**
  - 이유: `Data` 같은 generic 타입으로 우회하면 (1) 캐시 효율 저하(매 호출 디코딩), (2) 테스트 mock 복잡, (3) 실무 표준(Kingfisher, SDWebImage 등) 패턴과 어긋남
  - 적용 기준: "OS API 추상화"가 명백한 경우로 한정. Camera, Location, Notification 등 OS 의존성이 본질인 인프라에 한해 같은 기준 적용

## Interface 추상화 규칙

외부 IO(Network, Storage, Image, Repository)를 추상화하는 모든 protocol은 **async 메서드**로 정의한다.

### 이유

1. **향후 store 교체 안정성** — UserDefaults → CoreData/SwiftData/Remote 등으로 교체 시 인터페이스 시그니처를 바꾸지 않아도 됨
2. **컴파일러가 thread-safety를 보장** — 구현체가 `actor`를 채택할 수 있어 `NSLock + @unchecked Sendable` 패턴 불필요
3. **data race 원천 차단** — sync protocol에 `@unchecked Sendable`로 lock을 감싸는 패턴은 lock 밖 읽기 오류가 컴파일 타임에 잡히지 않음

### 예외

순수 계산/변환 함수(Mapper, Formatter 등)는 부작용과 I/O가 없으므로 sync 유지.

### 적용 범위

| 분류 | async 필수 | 예외(sync 유지) |
|---|---|---|
| Storage (`KeyValueStorageProtocol`) | `data`, `setData`, `removeObject` | — |
| Repository (`RecentKeywordRepositoryProtocol`, `GitHubRepositoryProtocol`) | 전 메서드 | — |
| UseCase (`RecentKeywordUseCase`, `AutoCompleteUseCase`, `SearchRepositoriesUseCase`) | 전 메서드 | — |
| Mapper | — | 전 메서드 |

## Router 패턴

- `AppRouter`(`@Observable`, `@MainActor`)가 `NavigationStack`의 path를 보유
- `Destination` enum의 각 case는 Feature Interface의 `*Destination` struct를 직접 보유
  - `case webView(WebViewDestination)`
- 검색 결과는 별도 push가 아니라 `SearchViewModel.State.results(SearchResultViewModel)` 로 SearchView 내부에서 렌더 — `AppRouter.path`에 추가되지 않는다 (예시 화면이 large title을 유지하면서 결과를 보여주는 동작과 일치)
- ViewModel은 `onRequestWebView: ((Repository) -> Void)?` 같은 closure로 Router와 분리됨 (WebView push만 Router 경유)
- DI Container가 ViewModel 만들면서 Router를 closure로 주입. 결과 화면처럼 화면 안에서 동적으로 만들어지는 sub-VM은 factory closure(`makeSearchResultViewModel`)로 주입

자세한 코드 예시는 [plan.md `### Router 패턴`](plan.md) 참조.
