# AI 활용 내역

> 컬리 채용 공고의 우대사항 **"생성형 AI 적극 활용"**에 대한 활용 내역 정리입니다.
> 본 프로젝트는 **계획 → 설계 → 구현 → 리뷰** 전 단계에서 Claude Code(Anthropic)와 Gemini Code Review(Google)를 적극 활용했습니다.

---

## 사용한 AI 도구

| 도구 | 모델 | 용도 |
|---|---|---|
| Claude Code (CLI) | Claude Opus 4.7 (1M context) | 계획서 작성, 구조 설계, 코드 작성, 사전 코드 리뷰 |
| Gemini Code Review | gemini-2.0-flash-exp | PR 자동 코드 리뷰 (GitHub Actions, 별도 관리) |

## 단계별 활용

### 1. 계획 단계 — Claude Code

- **요구사항 분석**: 채용 공고의 자격요건/우대사항을 평가 포인트로 분해 → 기술 스택 결정 근거화
- **기술 스택 매트릭스 작성**: SwiftUI vs UIKit, SwiftPM vs Tuist, microfeatures 5-target 패턴 채택 근거 정리
- **PR 분할 설계**: 15개 PR로 단일책임/리뷰가능 크기 보장 + 의존성 그래프 작성
- **결과물**: [docs/plan.md](plan.md) (~900줄, 본 프로젝트의 single source of truth)

### 2. 구조 정합성 검토 — Claude Code

- plan.md 초안에서 **WebViewDestination이 정의되었지만 AppRouter가 사용하지 않는** 정합성 깨짐 발견 → AppRouter Destination을 Feature Interface의 struct를 직접 보유하도록 수정
- 중복된 Gemini workflow YAML 블록 발견 → 제거
- AsyncSequence가 스택에 명시되었지만 실코드 예시에 없음 → 정직하게 스택에서 제거
- debounce 테스트 가능성을 위해 `Clock` 주입 도입
- 모든 화면 구현 완료 후 사용자가 **예시 이미지를 다시 보여주며 "검색 결과가 push가 아닌 것 같다"** 라고 지적 → Claude가 (a) large title 유지 + 취소 버튼 + 스크롤 시 collapse가 모두 iOS `.searchable`의 기본 동작임을 확인 (b) 영향 범위(AppRouter / AppRootView / SearchView / SearchViewModel / SearchResultView + 스냅샷 4장 + 문서 3건) 추적 → same-screen state 전환으로 리팩터링 (PR `refactor/search-result-inline-state`)

### 3. 코딩 정책 수립 — Claude Code

- `CLAUDE.md` + `docs/architecture.md, coding-style.md, testing.md, api.md`로 정책 분할
- Claude Code의 file import 문법(`@docs/...`)으로 인덱스(CLAUDE.md) 가볍게 유지

### 4. 구현 단계 — Claude Code

- 각 모듈의 Interface 설계 (protocol, Entity, Destination)
- ViewModel/View 골격 작성
- UseCase/Repository 구현
- 테스트 코드 작성 (Domain/Data/VM/Snapshot)

### 5. 사전 코드 리뷰 — Claude Code `/code-review`

- 매 PR 작성 직전 로컬에서 `/code-review` 실행 → 지적사항 반영 후 push
- 큰 변경엔 `/code-review ultra` (다중 에이전트 클라우드 리뷰) 추가

### 6. PR 자동 리뷰 — Gemini Code Review

- GitHub Actions 워크플로(별도 관리)가 PR 생성/업데이트 시 자동으로 diff 분석 → PR 코멘트
- iOS Swift + Modular Clean Architecture 관점에서 모듈 의존성 위반, force unwrap, async/await 누락, 메모리 누수, 테스트 누락 등을 중점 체크

## 의사결정 흐름 예시

**"WebView 모듈을 단일 모듈로 단순화할까, 5-target 유지할까?"**

Claude가 두 옵션의 trade-off 제시:
- A. 단일 모듈: 화면 1개라 microfeatures 오버킬 → 단순
- B. 5-target 유지 + WebViewDestination 실사용: 패턴 일관성 ↑

→ 사용자가 B 선택 ("다 모듈화해야지"). Claude가 그에 맞춰 `AppRouter`를 `WebViewDestination` 받도록 정합화.

**시사점**: AI가 옵션과 trade-off를 명시 → 사람이 의사결정 → AI가 그 결정의 모든 파급(plan/README/AppRouter 시그니처)을 일괄 정합화.

## 인간 의사결정과 AI 실행의 분담

- **인간(개발자)**: 채용 평가 포인트 해석, 우선순위, 디자인 trade-off 선택, 최종 코드 리뷰
- **AI(Claude)**: 옵션 탐색, 정합성 검사, 보일러플레이트 작성, 문서 동기화, 사전 리뷰
- **AI(Gemini)**: 독립적 시각의 자동 리뷰

## 한계 / 검증

- AI가 제시한 코드는 항상 **빌드 + 테스트 + 시뮬레이터 실행** 검증 후 머지
- AI 제안에 동의하지 않으면 명시적으로 거부 (예: "structured Task" 용어는 부적절하다고 판단 → "Task"로 단순화)
- 의사결정 근거는 plan.md / 이 문서에 모두 기록

---

> **결론**: AI는 본 프로젝트에서 "더 빠르게 작성하는 타이핑 도구"가 아니라, **설계 정합성 / 의사결정 trade-off / 사전·사후 리뷰의 보조 두뇌**로 사용되었습니다.
