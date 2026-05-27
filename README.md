# Kurly GitHub Search

컬리 iOS 직무 1차 사전과제 — GitHub 저장소 검색 iOS 앱

> 본 레포는 **계획 단계**입니다. 구현은 이후 PR로 진행됩니다.

## 개요

GitHub Search API를 활용한 저장소 검색 iOS 앱.
검색 입력 / 자동완성 / 최근 검색어 관리 / 무한 스크롤 결과 / WebView 상세를 제공합니다.

## 기술 스택

- **iOS 17.0+**
- **SwiftUI** + `@Observable` + `NavigationStack`
- **async / await + AsyncSequence**
- **Modular + Clean Architecture** (Vertical Slicing, microfeatures 5-target)
- **SwiftPM** (Tuist 미사용)
- **프로덕션 외부 라이브러리 0** (순수 Swift)
- 테스트: `swift-snapshot-testing`
- Lint: `SwiftLint`
- CI: GitHub Actions (test, lint, Gemini PR review)

## 문서

- [📋 구현 계획서 (Plan)](docs/plan.md) — 아키텍처, 모듈 구조, PR 분할, CI 등 전체 설계

## 개발 워크플로우

1. `infra/skeleton`, `infra/ci` 브랜치로 뼈대 구축
2. 화면/모듈 단위 `feat/*` 브랜치 → PR
3. PR 전 로컬에서 **Claude Code 사전 리뷰** (`/code-review`)
4. PR 후 **Gemini PR 리뷰** (GitHub Actions 자동) + CI 통과
5. 모든 그린이면 `main` 머지

자세한 PR 분할은 [구현 계획서](docs/plan.md#개발-워크플로우-branch--pr--review) 참조.

## 실행

> 추후 `infra/skeleton` PR에서 Xcode 프로젝트와 SwiftPM 패키지를 추가합니다.

```bash
# (예정) SwiftPM 단독 테스트
cd Modules && swift test

# (예정) Xcode 통합 테스트
xcodebuild test \
  -project App/KurlyGitHubSearchApp.xcodeproj \
  -scheme KurlyGitHubSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'

# (예정) Lint
swiftlint --strict
```

## 라이센스

본 레포는 채용 사전과제 제출 목적입니다.
