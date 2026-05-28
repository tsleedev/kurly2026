# Coding Style

## 명명

- 타입: `UpperCamelCase` (`SearchViewModel`, `GitHubRepository`)
- 함수/변수: `lowerCamelCase` (`loadNextPageIfNeeded`, `recentKeywords`)
- 상수: `lowerCamelCase` (not SCREAMING_SNAKE)
- **Protocol / Impl 규칙 (하이브리드)** — 이름을 누가 "주인공"이냐로 결정:
  - **추상 역할이 주 이름**일 때 → protocol = 역할, impl = 역할 + `Impl`
    - `SearchRepositoriesUseCase` (protocol) + `SearchRepositoriesUseCaseImpl` (impl)
    - `RecentKeywordUseCase` + `RecentKeywordUseCaseImpl`
    - `AutoCompleteUseCase` + `AutoCompleteUseCaseImpl`
  - **구체 식별자가 주 이름**일 때 → protocol = 역할 + `Protocol`, impl = 구체 식별자
    - `GitHubRepositoryProtocol` + `GitHubRepository`
    - `KeyValueStorageProtocol` + `UserDefaultsStorage`
    - `APIClientProtocol` + `URLSessionAPIClient`
    - `ImageLoaderProtocol` + `ImageLoader`
  - 이유: UseCase는 "무엇을 하는가"가 핵심(추상 역할이 자연스러운 1급 이름), Repository/Storage/Client는 "무엇으로 하는가"가 정체성(구체 식별자가 자연스러운 1급 이름)
- Mock: `MockXxx` (Testing 모듈에 위치)
- 파일명: 타입명과 동일 (`SearchViewModel.swift`)

## 코드 규칙

- `final class` 기본 (상속이 명시적으로 필요한 경우만 open)
- 프로토콜 지향: 외부에서 구체 타입 대신 protocol 사용
- 생성자 주입 (singleton 금지)
- `@MainActor`는 UI 관련 ViewModel/View에만
- Domain layer는 `Foundation` only — UIKit/SwiftUI/외부 import 금지
- private(set) 적극 활용

## 금지 / 회피

- `force_cast` (`as!`), `force_try` (`try!`), `force_unwrapping` (`x!`), `implicitly_unwrapped_optional` (`var x: T!`) — 모두 SwiftLint error (unsafe unwrap 일관 금지)
- `print` (대신 OSLog 또는 throw)
- `DispatchQueue.main.async` (대신 `@MainActor` / `await MainActor.run`)
- Singleton (`shared`) — 생성자 주입으로 대체
- 전역 mutable state

## 동기화

### 권장 순위

1. **`actor`** — 기본. 외부 IO/Storage/Repository 구현체에 사용. 컴파일러가 isolation을 보장하므로 lock 코드 불필요.
2. **`OSAllocatedUnfairLock`** — 부득이하게 sync API + thread-safety가 필요할 때 (예: 어떤 외부 protocol이 sync로 고정된 자리). `NSLock`보다 성능 우위.
3. **`NSLock`** — 호환성·가독성이 더 중요하거나 단순한 보호가 필요할 때.

### 금지 패턴

`@unchecked Sendable + class + 비명시적 락` — 락 보호 범위가 명확하지 않으면 리뷰 시 data race 여부를 정적으로 알 수 없다.

부득이하게 사용해야 할 경우 반드시:
- (a) `actor`가 안 되는 명확한 이유를 주석으로 명시
- (b) 락으로 보호되는 모든 프로퍼티와 범위를 주석으로 명시

### Protocol 추상화 일관성

외부 IO 추상화는 sync 인터페이스 금지. 모든 외부 IO/Storage/Repository protocol은 async로 정의한다.  
자세한 근거는 [architecture.md - Interface 추상화 규칙](architecture.md) 참조.

## 주석

- 코드가 무엇을 하는지 설명하지 않는다. 식별자 이름으로 표현
- WHY가 비자명할 때만 한 줄 주석 (제약, 함정, 외부 이슈 우회)
- 공용 API에는 짧은 docstring (`/// ...`)

## 파일 구조

- `// MARK: -` 섹션 구분: `// MARK: - Init`, `// MARK: - Public`, `// MARK: - Private`
- import 순서: Apple frameworks → 외부 라이브러리 → 자체 모듈 (Interface → Source)
- 한 파일당 한 primary type (헬퍼 nested type, fileprivate extension 예외)

## SwiftLint

`.swiftlint.yml` 참조. CI에서 `swiftlint --strict` 통과 필수.

opt-in으로 강화된 룰:
- `force_unwrapping`, `implicit_return`, `empty_count`, `closure_spacing`
- `contains_over_first_not_nil`, `first_where`, `last_where`
- `explicit_init`, `redundant_nil_coalescing`, `sorted_first_last`, `unused_import`

길이 제한:
- line: 140 warn / 200 error
- file: 500 warn / 800 error
- function body: 60 warn / 120 error
- type body: 300 warn / 500 error
