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

- `force_cast` (`as!`), `force_try` (`try!`), `force_unwrapping` (`x!`) — SwiftLint error
- `implicitly_unwrapped_optional` (`var x: T!`) — warning
- `print` (대신 OSLog 또는 throw)
- `DispatchQueue.main.async` (대신 `@MainActor` / `await MainActor.run`)
- Singleton (`shared`) — 생성자 주입으로 대체
- 전역 mutable state

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
