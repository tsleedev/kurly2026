# Project Style Guide for Gemini Code Assist

이 파일은 Gemini Code Assist가 PR 리뷰 시 참조하는 우리 프로젝트의 코딩 규칙 요약입니다.
정식 / 상세 버전: [docs/coding-style.md](../docs/coding-style.md), [docs/architecture.md](../docs/architecture.md)

## Project Snapshot

- **컬리 iOS 사전과제** — GitHub 저장소 검색 앱 (Public 제출용)
- iOS 17.0+, SwiftUI, `@Observable`, async/await + Task
- SwiftPM modular monorepo (no Tuist)
- **외부 라이브러리 0** (프로덕션). 테스트만 `swift-snapshot-testing` 허용
- 화면 3개: SearchView, SearchResultView, RepositoryWebView

## Architecture (Vertical Slicing + microfeatures 5-target)

```
Modules/Sources/
  Core/       (Network, Storage, ImageLoading)
  Feature/    (Search, WebView)
```

각 모듈은 `Interface / Source / Testing / Tests` sub-target 으로 분리. `Interface`는 Foundation only.

### 레이어 import 규칙 (위반 시 high-priority 지적)
- `*Interface/`: Foundation only — UIKit/SwiftUI/외부 라이브러리 금지
- Source 내 `Domain/` 폴더: Foundation + own Interface only
- Source 내 `Data/` 폴더: Foundation + 자신/외부 Interface
- Source 내 `Presentation/` 폴더: SwiftUI + own Interface + Domain
- App: 모든 모듈 (Composition Root)
- **Feature 모듈끼리 직접 import 금지** — Router 패턴으로만 연결

## Naming (하이브리드 규칙)

**의도된 패턴** — 주 이름이 누구인지로 결정. 불일치로 보지 말 것.

- **추상 역할이 주 이름** → `Xxx` protocol + `XxxImpl` impl
  - 예: `SearchRepositoriesUseCase` + `SearchRepositoriesUseCaseImpl`
  - 예: `RecentKeywordUseCase` + `RecentKeywordUseCaseImpl`
- **구체 식별자가 주 이름** → `XxxProtocol` + 구체명 impl
  - 예: `GitHubRepositoryProtocol` + `GitHubRepository`
  - 예: `KeyValueStorageProtocol` + `UserDefaultsStorage`
  - 예: `APIClientProtocol` + `URLSessionAPIClient`
  - 예: `ImageLoaderProtocol` + `ImageLoader`
- Mock: `MockXxx` (Testing 모듈에 위치)

## 금지 / 회피 패턴 (high-priority로 지적해도 됨)

- `as!`, `try!`, `x!` (force cast/try/unwrap) — SwiftLint error로도 잡힘
- Singleton (`.shared`) — 생성자 주입으로 대체
- `print()` — 로깅 필요하면 OSLog
- `DispatchQueue.main.async` — `@MainActor` / `await MainActor.run`
- 전역 mutable state
- Feature 모듈에서 다른 Feature 모듈 import (Router로 연결)

## 비동기 / 시간 의존 코드

- `Clock` 프로토콜 주입 (debounce, throttle 같은 시간 의존 코드)
- 직접 `Task.sleep(for:)` 호출 시 테스트 가능성 ↓ → 권장 안 함

## 테스트

- Mock은 `<Feature>Testing` target에서만 노출 (App에서 import 금지)
- ViewModel 테스트는 Mock UseCase 주입
- Repository 테스트는 `URLProtocolStub` 사용
- Snapshot 테스트는 iPhone 17 / iOS latest 기준

## 무시해도 되는 false positive

- **Xcode 26.x 버전 메타데이터** (`CreatedOnToolsVersion`, `LastUpgradeCheck`, `LastSwiftUpdateCheck`, `IPHONEOS_DEPLOYMENT_TARGET = 26.x` 등)는 Apple의 iOS 26 버전 정렬(2025 WWDC) 이후 실제 유효 값. "invalid"로 지적하지 말 것.
- 단 `IPHONEOS_DEPLOYMENT_TARGET`이 plan(iOS 17.0+)과 다르면 그건 진짜 지적사항.
- `Modules/Package.resolved`는 의도적으로 커밋 (빌드 재현성). "왜 커밋했나" 지적하지 말 것.

## PR 규모

- 한 PR = 한 책임. plan.md의 PR 분할표 참조.
- 각 PR은 빌드/테스트 그린 + 단일 책임이어야 머지.
