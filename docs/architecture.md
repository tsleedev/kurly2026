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
 ├── AppRouter (Destination = SearchResultDestination | WebViewDestination)
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
| `*Interface/` | Foundation only |
| `*/Domain/` (UseCase, Entity) | Foundation only |
| `*/Data/` (Repository, DTO) | Foundation + own Interface + 외부 Interface |
| `*/Presentation/` (View, ViewModel) | SwiftUI + own Interface + Domain |
| `App/` | 모든 모듈 (Composition Root) |

위반 사례:
- ❌ `Interface`에서 SwiftUI/UIKit import
- ❌ `Search`(Source)에서 `WebView` import (Router로만 연결)
- ❌ `Interface` → `Source` import (방향 역전)

## Router 패턴

- `AppRouter`(`@Observable`, `@MainActor`)가 `NavigationStack`의 path를 보유
- `Destination` enum의 각 case는 Feature Interface의 `*Destination` struct를 직접 보유
  - `case searchResult(SearchResultDestination)`
  - `case webView(WebViewDestination)`
- ViewModel은 `onRequestSearch: ((String) -> Void)?` 같은 closure로 Router와 분리됨
- DI Container가 ViewModel 만들면서 Router를 closure로 주입

자세한 코드 예시는 [plan.md `### Router 패턴`](plan.md) 참조.
