# Kurly GitHub Search

## Project Context

컬리 iOS 사전과제 — GitHub 저장소 검색 앱.
SwiftUI + Modular Clean Architecture + microfeatures 5-target.

상세 계획서: [docs/plan.md](docs/plan.md)

## Tech Stack

- iOS 17+, SwiftUI, `@Observable`, async/await + Task
- SwiftPM (Tuist 미사용), 프로덕션 외부 라이브러리 0
- 테스트: XCTest + swift-snapshot-testing
- CI: GitHub Actions (test, lint) + Gemini PR 자동 리뷰

## Policy Documents

@docs/architecture.md  - 모듈 구조, 의존성 규칙, microfeatures 5-target
@docs/coding-style.md  - 명명 규칙, SwiftLint 룰
@docs/testing.md       - 테스트 작성 가이드 (Domain / Data / VM / Snapshot)
@docs/api.md           - GitHub Search API 명세, 에러 매핑, rate limit
@docs/ai-usage.md      - AI 활용 내역 (제출 시 README에서 링크)

## Key Commands

| 작업 | 명령 |
|---|---|
| 모듈 빌드 | `cd Modules && swift build` |
| 모듈 테스트 | `cd Modules && swift test` |
| 앱 열기 | `open App/KurlyGitHubSearchApp.xcodeproj` |
| Lint | `swiftlint --strict` |

## Critical Rules

- `main` 직접 push 금지 (PR 머지만). 단 초기 부트스트랩(`infra/skeleton`, `infra/ci`)은 예외
- 각 PR은 빌드/테스트 그린 + Claude 사전 리뷰(`/code-review`) + Gemini 자동 리뷰 통과해야 머지
- 프로덕션 외부 라이브러리 0. 테스트용 `swift-snapshot-testing`, lint용 `SwiftLint`만 허용
- Domain layer는 `Foundation` only — UIKit/SwiftUI/외부 라이브러리 import 금지
- `Interface` 모듈은 다른 Feature의 `Interface`에만 의존 (Source 의존 금지)
- `force_cast` / `force_try` / `force_unwrapping` SwiftLint error
