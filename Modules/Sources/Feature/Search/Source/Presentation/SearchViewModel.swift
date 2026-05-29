import Foundation
import Observation
import SearchInterface

/// 검색 진입 화면(SearchView) ViewModel.
///
/// 두 상태를 가진다:
/// - `.recent([RecentKeyword])`: 검색어가 비어있을 때. 최근 검색 리스트 표시.
/// - `.autocomplete([RecentKeyword])`: 검색어 입력 중. prefix 매칭 자동완성 표시.
///
/// 자동완성 진입/이탈은 300ms 디바운스. 매 키 입력마다 직전 Task를 취소하고 새로 스케줄한다.
/// 시계는 `Clock` 주입으로 추상화 — 테스트에서 `TestClock`으로 결정론적 검증.
///
/// Router는 closure(`onRequestSearch`)로 위임받아 ViewModel이 AppRouter 타입을 모르게 한다.
@MainActor
@Observable
public final class SearchViewModel {

    // MARK: - State

    public enum State: Equatable {
        case recent([RecentKeyword])
        case autocomplete([RecentKeyword])
    }

    public private(set) var state: State = .recent([])

    /// `.searchable`과 양방향 바인딩되는 검색어.
    public var query: String = ""

    // MARK: - Router seam

    public var onRequestSearch: ((String) -> Void)?

    // MARK: - Dependencies

    private let recentKeywordUseCase: RecentKeywordUseCase
    private let autoCompleteUseCase: AutoCompleteUseCase
    private let clock: any Clock<Duration>
    private let debounceDuration: Duration

    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    /// 입력/액션마다 증가시키는 세대 카운터.
    ///
    /// refreshState는 await 후 state를 갱신하기 직전 자기 세대가 여전히 최신인지 확인한다.
    /// 늦게 도착한 옛 await 결과가 새 상태(.recent / 다른 autocomplete)를 덮어쓰는 race를 차단한다.
    @ObservationIgnored private var generation: UInt64 = 0

    // MARK: - Init

    public init(
        recentKeywordUseCase: RecentKeywordUseCase,
        autoCompleteUseCase: AutoCompleteUseCase,
        clock: any Clock<Duration> = ContinuousClock(),
        debounceDuration: Duration = .milliseconds(300)
    ) {
        self.recentKeywordUseCase = recentKeywordUseCase
        self.autoCompleteUseCase = autoCompleteUseCase
        self.clock = clock
        self.debounceDuration = debounceDuration
    }

    // MARK: - Lifecycle

    public func onAppear() async {
        state = .recent(await recentKeywordUseCase.recent())
    }

    // MARK: - User actions

    public func onQueryChanged(_ newValue: String) {
        debounceTask?.cancel()
        generation &+= 1
        let currentGeneration = generation
        let clock = self.clock
        let duration = self.debounceDuration
        debounceTask = Task { @MainActor [weak self] in
            try? await clock.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            await self.refreshState(for: newValue, generation: currentGeneration)
        }
    }

    public func onSubmit() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        query = trimmed
        invalidatePendingRefresh()
        await recentKeywordUseCase.save(trimmed)
        state = .recent(await recentKeywordUseCase.recent())
        onRequestSearch?(trimmed)
    }

    public func onTapRecent(_ keyword: String) async {
        query = keyword
        invalidatePendingRefresh()
        await recentKeywordUseCase.save(keyword)
        state = .recent(await recentKeywordUseCase.recent())
        onRequestSearch?(keyword)
    }

    public func onConfirmDelete(_ keyword: String) async {
        invalidatePendingRefresh()
        await recentKeywordUseCase.delete(keyword)
        state = .recent(await recentKeywordUseCase.recent())
    }

    public func onConfirmDeleteAll() async {
        invalidatePendingRefresh()
        await recentKeywordUseCase.deleteAll()
        state = .recent([])
    }

    // MARK: - Private

    /// 진행 중인 debounce task를 취소하고 generation을 증가시켜, 늦게 도착할 옛 refreshState 결과가 새 상태를 덮어쓰지 못하게 한다.
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
