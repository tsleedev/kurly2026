# Testing

## 레이어별 테스트 매트릭스

| 레이어 | 위치 | 도구 | 무엇을 검증 |
|---|---|---|---|
| Domain (UseCase) | `<Feature>Tests/Domain/` | XCTest + Mock | 입력 → 출력 매핑, 정책, 에러 분기 |
| Data (Repository, Mapper) | `<Feature>Tests/Data/` | XCTest + URLProtocolStub | API 응답 매핑, 에러 매핑 |
| Presentation (ViewModel) | `<Feature>Tests/Presentation/` | XCTest + Mock UseCase | 상태 전환, debounce, Router 호출 |
| UI (Snapshot) | `<Feature>Tests/Snapshot/` | swift-snapshot-testing | 화면 렌더링 회귀 |
| Networking (통합) | `NetworkingTests/` | XCTest + URLProtocolStub | URLSession 경로, 에러 매핑 |

## 핵심 규칙

- **Mock은 `<Feature>Testing` target에서 제공**. Tests target은 Testing target을 import해서 사용
- **Repository는 protocol에 의존, 절대 구체 URLSession 호출 안 함**
- **debounce / 시간 의존 코드는 `Clock` 주입**해서 `TestClock`으로 결정론적 테스트
- **Snapshot 기록은 macOS Simulator (iPhone 17, iOS latest) 기준**. CI도 동일 환경
- 새 기능 추가 시 **최소 Domain + Presentation** 테스트는 동반

## 패턴

### UseCase 테스트

```swift
final class SearchRepositoriesUseCaseTests: XCTestCase {
    func test_execute_정상응답이면_SearchResult_반환() async throws {
        let mock = MockGitHubRepository(stub: .success(.sample))
        let sut = SearchRepositoriesUseCaseImpl(repository: mock)
        let result = try await sut.execute(query: "swift", page: 1)
        XCTAssertEqual(result.totalCount, 266_714)
    }
}
```

### ViewModel + Clock 주입 (debounce)

```swift
@MainActor
final class SearchViewModelTests: XCTestCase {
    func test_onQueryChanged_300ms_뒤에_autocomplete로_전환() async {
        let clock = TestClock()
        let sut = SearchViewModel(
            recentKeywordUseCase: MockRecentKeywordUseCase(),
            autoCompleteUseCase: MockAutoCompleteUseCase(suggestions: [.swift]),
            clock: clock
        )
        sut.onQueryChanged("swif")
        await clock.advance(by: .milliseconds(300))
        // assert state == .autocomplete([...])
    }
}
```

`TestClock`은 외부 라이브러리 0 정책상 직접 구현 (`Clock<Duration>` 준수, advance 메서드 보유).

### Snapshot 테스트

```swift
final class SearchViewSnapshotTests: XCTestCase {
    func test_빈_최근검색() {
        let view = SearchView(viewModel: .preview(state: .recent([])))
        assertSnapshot(of: view.frame(width: 390, height: 844), as: .image)
    }
}
```

스냅샷 record 모드는 PR에서 명시적으로 합의 후만 사용. 평소엔 read-only.

### Networking 테스트 (URLProtocolStub)

```swift
final class GitHubRepositoryTests: XCTestCase {
    func test_search_정상_응답_매핑() async throws {
        URLProtocolStub.stub(data: Fixture.searchSwift)
        let sut = GitHubRepository(client: URLSessionAPIClient(session: .stubbed))
        let result = try await sut.search(query: "swift", page: 1)
        XCTAssertEqual(result.repositories.first?.name, "swift")
    }
}
```

## CI

GitHub Actions에서 `swift test` (Modules) + `xcodebuild test` (Snapshot 포함) 모두 그린이어야 머지.
