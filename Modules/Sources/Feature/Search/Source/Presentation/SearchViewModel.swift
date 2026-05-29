import Foundation
import Observation
import SearchInterface

/// 검색 진입 화면(SearchView) ViewModel.
///
/// 세 상태를 가진다:
/// - `.recent([RecentKeyword])`: 검색어가 비어있을 때. 최근 검색 리스트 표시.
/// - `.autocomplete([RecentKeyword])`: 검색어 입력 중. prefix 매칭 자동완성 표시.
/// - `.results(SearchResultViewModel)`: submit / 최근·자동완성 탭 후. 같은 화면 내에서 결과 리스트 표시.
///
/// 결과는 별도 push 화면이 아니라 `.searchable` + large title이 active인 채로 같은 화면에서 그려진다
/// (예시 2와 동일한 시각 효과). 결과 화면 자체 로직은 `SearchResultViewModel`이 그대로 책임진다.
///
/// 자동완성 진입/이탈은 300ms 디바운스. 매 키 입력마다 직전 Task를 취소하고 새로 스케줄한다.
/// 시계는 `Clock` 주입으로 추상화 — 테스트에서 `TestClock`으로 결정론적 검증.
@MainActor
@Observable
public final class SearchViewModel {

    // MARK: - State

    public enum State {
        case recent([RecentKeyword])
        case autocomplete([RecentKeyword])
        case results(SearchResultViewModel)
    }

    public private(set) var state: State = .recent([])

    /// `.searchable`과 양방향 바인딩되는 검색어.
    public var query: String = ""

    // MARK: - Dependencies

    private let recentKeywordUseCase: RecentKeywordUseCase
    private let autoCompleteUseCase: AutoCompleteUseCase
    private let makeSearchResultViewModel: @MainActor (SearchResultDestination) -> SearchResultViewModel
    private let clock: any Clock<Duration>
    private let debounceDuration: Duration

    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    /// 입력/액션마다 증가시키는 세대 카운터.
    ///
    /// refreshState는 await 후 state를 갱신하기 직전 자기 세대가 여전히 최신인지 확인한다.
    /// 늦게 도착한 옛 await 결과가 새 상태(.recent / 다른 autocomplete / .results)를 덮어쓰는 race를 차단한다.
    @ObservationIgnored private var generation: UInt64 = 0

    /// `.task` 재발화(예: WebView push 후 pop) 시 onAppear가 .results state를 .recent로 덮어쓰지 않도록 가드.
    /// `SearchResultViewModel.hasInitiated`와 동일한 패턴.
    @ObservationIgnored private var hasInitiated = false

    /// 가장 최근에 만든 SearchResultViewModel을 query 키로 캐시.
    /// 같은 query로 재진입 시(.results → typing → .autocomplete → .recent → 다시 submit) 기존 VM을 복원해
    /// 페이지네이션/스크롤 위치를 보존한다. 다른 query 진입 시 자연스럽게 교체되어 메모리는 최대 1개만 유지.
    @ObservationIgnored private var resultViewModelCache: (query: String, viewModel: SearchResultViewModel)?

    // MARK: - Init

    public init(
        recentKeywordUseCase: RecentKeywordUseCase,
        autoCompleteUseCase: AutoCompleteUseCase,
        makeSearchResultViewModel: @escaping @MainActor (SearchResultDestination) -> SearchResultViewModel,
        clock: any Clock<Duration> = ContinuousClock(),
        debounceDuration: Duration = .milliseconds(300)
    ) {
        self.recentKeywordUseCase = recentKeywordUseCase
        self.autoCompleteUseCase = autoCompleteUseCase
        self.makeSearchResultViewModel = makeSearchResultViewModel
        self.clock = clock
        self.debounceDuration = debounceDuration
    }

    // MARK: - Lifecycle

    /// 첫 진입에만 최근 검색을 로드. NavigationStack push로 SearchView가 화면을 떠났다 돌아올 때
    /// `.task`가 재발화해도 .results / .autocomplete 같은 상태를 .recent로 덮어쓰지 않는다.
    public func onAppear() async {
        guard !hasInitiated else { return }
        hasInitiated = true
        let requested = generation
        let recent = await recentKeywordUseCase.recent()
        guard requested == generation else { return }
        state = .recent(recent)
    }

    // MARK: - User actions

    public func onQueryChanged(_ newValue: String) {
        debounceTask?.cancel()
        generation &+= 1
        let requested = generation
        // 빈 입력은 사용자가 즉시 최근 검색을 보길 기대 — debounce 생략하고 바로 refresh 스케줄.
        // `.results` 상태에서 .searchable 취소 버튼을 누르면 query=""가 들어와 이 경로로 복귀한다.
        if newValue.isEmpty {
            debounceTask = Task { @MainActor [weak self] in
                guard !Task.isCancelled, let self else { return }
                await self.refreshState(for: "", generation: requested)
            }
            return
        }
        let clock = self.clock
        let duration = self.debounceDuration
        debounceTask = Task { @MainActor [weak self] in
            try? await clock.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            await self.refreshState(for: newValue, generation: requested)
        }
    }

    public func onSubmit() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        query = trimmed
        await startResults(for: trimmed)
    }

    public func onTapRecent(_ keyword: String) async {
        query = keyword
        await startResults(for: keyword)
    }

    public func onConfirmDelete(_ keyword: String) async {
        invalidatePendingRefresh()
        let requested = generation
        await recentKeywordUseCase.delete(keyword)
        let recent = await recentKeywordUseCase.recent()
        guard requested == generation else { return }
        state = .recent(recent)
    }

    public func onConfirmDeleteAll() async {
        invalidatePendingRefresh()
        let requested = generation
        await recentKeywordUseCase.deleteAll()
        guard requested == generation else { return }
        state = .recent([])
    }

    // MARK: - Test seam

    /// 진행 중인 debounce/refresh task가 끝날 때까지 대기. 테스트에서 unstructured Task의 스케줄링
    /// 지연으로 인한 flakiness를 제거하기 위한 유일 용도.
    public func waitForPendingRefresh() async {
        await debounceTask?.value
    }

    // MARK: - Private

    /// onSubmit / onTapRecent 공통 흐름:
    /// (1) 진행 중인 debounce 취소  (2) 결과 VM 준비(캐시 우선)  (3) state를 .results로 동기 전환  (4) save는 백그라운드.
    ///
    /// state를 save **이전**에 설정해 사용자는 결과 화면을 즉시 본다. save가 await인 동안 사용자가
    /// 다른 입력을 하면 onQueryChanged가 새 debounce를 스케줄해 자연스럽게 화면이 전환된다 —
    /// save 결과를 기다리느라 submit이 묵음으로 실패하는 경로가 없다.
    private func startResults(for keyword: String) async {
        invalidatePendingRefresh()
        state = .results(resultViewModel(for: keyword))
        await recentKeywordUseCase.save(keyword)
    }

    /// 같은 query면 캐시된 VM 반환(기존 페이지/스크롤 보존), 아니면 factory로 새로 만들어 캐시 교체.
    private func resultViewModel(for query: String) -> SearchResultViewModel {
        if let cached = resultViewModelCache, cached.query == query {
            return cached.viewModel
        }
        let viewModel = makeSearchResultViewModel(SearchResultDestination(query: query))
        resultViewModelCache = (query: query, viewModel: viewModel)
        return viewModel
    }

    /// 진행 중인 debounce task를 취소하고 generation을 증가시켜, 늦게 도착할 옛 refresh/액션 결과가 새 상태를 덮어쓰지 못하게 한다.
    private func invalidatePendingRefresh() {
        debounceTask?.cancel()
        generation &+= 1
    }

    private func refreshState(for query: String, generation requested: UInt64) async {
        let newState: State
        if query.isEmpty {
            newState = .recent(await recentKeywordUseCase.recent())
        } else {
            newState = .autocomplete(await autoCompleteUseCase.suggestions(for: query))
        }
        guard requested == generation else { return }
        state = newState
    }
}

// MARK: - State Equatable

/// `.results`는 ref-type VM을 보유하므로 identity 기반 비교. 다른 두 case는 값 비교.
/// 테스트에서 `XCTAssertEqual(sut.state, .recent([...]))`를 그대로 쓸 수 있게 유지.
extension SearchViewModel.State: Equatable {
    public static func == (lhs: SearchViewModel.State, rhs: SearchViewModel.State) -> Bool {
        switch (lhs, rhs) {
        case (.recent(let left), .recent(let right)):
            return left == right
        case (.autocomplete(let left), .autocomplete(let right)):
            return left == right
        case (.results(let left), .results(let right)):
            return left === right
        default:
            return false
        }
    }
}
