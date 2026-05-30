import Foundation
import Observation
import NetworkingInterface
import SearchInterface

/// 검색 결과 화면 ViewModel.
///
/// `state`는 페이지 누적된 SearchResult를 보유한다 — 페이지 추가 로드 시 기존 repositories에
/// append 한다. `paginationState`는 다음 페이지 로드의 별도 상태(idle/loading/failed)를 추적해
/// 하단 인디케이터/에러 배너 UI에 사용한다.
///
/// 액션마다 generation을 증가시켜, 늦게 도착한 옛 load 결과가 새 상태를 덮어쓰는 race를 차단한다.
/// (재시도와 in-flight 로드가 겹칠 때 안전)
@MainActor
@Observable
public final class SearchResultViewModel {

    // MARK: - State

    public enum State: Equatable {
        case loading
        case loaded(SearchResult)
        case failed(NetworkError)
    }

    public enum PaginationState: Equatable {
        /// 다음 페이지 트리거 대기. (hasNextPage가 false면 더 이상 발화 안 함)
        case idle
        case loading
        case failed(NetworkError)
    }

    public private(set) var state: State = .loading
    public private(set) var paginationState: PaginationState = .idle

    public let query: String

    /// 셀이 끝에서 몇 번째 안에 들어왔을 때 다음 페이지를 prefetch 할지.
    public let prefetchThreshold: Int

    // MARK: - Router seam

    /// 결과 셀 탭 시 호출. AppDIContainer가 closure로 주입해 WebViewDestination 변환을 담당.
    public var onRequestWebView: ((Repository) -> Void)?

    // MARK: - Dependencies

    private let searchUseCase: SearchRepositoriesUseCase
    @ObservationIgnored private var generation: UInt64 = 0
    /// 첫 onAppear에서 1회만 로드. .task가 view 재진입 등으로 다시 발화해도 자동 재요청하지 않는다.
    /// 명시적 재시도는 `onRetry()` 사용 (사용자가 다시 시도 버튼 탭).
    @ObservationIgnored private var hasInitiated = false

    // MARK: - Init

    public init(
        query: String,
        searchUseCase: SearchRepositoriesUseCase,
        prefetchThreshold: Int = 5
    ) {
        self.query = query
        self.searchUseCase = searchUseCase
        self.prefetchThreshold = prefetchThreshold
    }

    // MARK: - Lifecycle

    public func onAppear() async {
        guard !hasInitiated else { return }
        hasInitiated = true
        await load()
    }

    // MARK: - User actions

    public func onRetry() async {
        await load()
    }

    public func onTapRepository(_ repository: Repository) {
        onRequestWebView?(repository)
    }

    /// 셀 `.onAppear`에서 호출. currentItem이 끝에서 `prefetchThreshold` 이내면 다음 페이지를 로드한다.
    ///
    /// 가드:
    /// - 현재 상태가 `.loaded`이어야 함
    /// - 현재 페이지에 `hasNextPage`가 true여야 함
    /// - `paginationState`가 `.idle`이어야 함 (loading/failed 중복 발화 방지)
    public func loadNextPageIfNeeded(currentItem: Repository) async {
        guard case .loaded(let current) = state,
              current.hasNextPage,
              paginationState == .idle else { return }
        guard let index = current.repositories.firstIndex(where: { $0.id == currentItem.id }) else { return }
        guard index >= current.repositories.count - prefetchThreshold else { return }
        await loadNextPage(after: current)
    }

    /// 다음 페이지 로드를 사용자가 명시적으로 재시도. paginationState=.failed에서 호출.
    /// 이미 .loading 중이면 중복 발화하지 않는다(스팸 탭 방지).
    public func retryNextPage() async {
        guard case .loaded(let current) = state, current.hasNextPage else { return }
        guard paginationState != .loading else { return }
        await loadNextPage(after: current)
    }

    // MARK: - Private

    private func load() async {
        generation &+= 1
        let requested = generation
        state = .loading
        paginationState = .idle
        do {
            let result = try await searchUseCase.execute(query: query, page: 1)
            guard requested == generation else { return }
            state = .loaded(result)
        } catch is CancellationError {
            // .task가 view 사라짐으로 인해 취소된 경우 — 사용자에게 에러를 보여주지 않는다.
            // hasInitiated를 다시 false로 돌려 다음 onAppear에서 재시도 가능하게 한다
            // (VM이 재사용되는 시나리오에서 무한 .loading에 갇히지 않도록).
            hasInitiated = false
            return
        } catch NetworkError.cancelled {
            hasInitiated = false
            return
        } catch let error as NetworkError {
            guard requested == generation else { return }
            state = .failed(error)
        } catch {
            guard requested == generation else { return }
            state = .failed(.transport)
        }
    }

    private func loadNextPage(after current: SearchResult) async {
        let requested = generation
        paginationState = .loading
        do {
            let next = try await searchUseCase.execute(query: query, page: current.page + 1)
            guard requested == generation, case .loaded(let snapshot) = state else { return }
            // GitHub Search는 페이지 경계에서 중복 아이템을 줄 수 있다(검색 중 별점 변동 등).
            // Repository.id 기준으로 dedup해 ForEach가 duplicate id로 깨지지 않게 한다.
            let existingIDs = Set(snapshot.repositories.map(\.id))
            let appended = next.repositories.filter { !existingIDs.contains($0.id) }
            let merged = SearchResult(
                totalCount: next.totalCount,
                repositories: snapshot.repositories + appended,
                page: next.page,
                hasNextPage: next.hasNextPage
            )
            state = .loaded(merged)
            paginationState = .idle
        } catch is CancellationError {
            guard requested == generation else { return }
            paginationState = .idle
        } catch NetworkError.cancelled {
            guard requested == generation else { return }
            paginationState = .idle
        } catch let error as NetworkError {
            guard requested == generation else { return }
            paginationState = .failed(error)
        } catch {
            guard requested == generation else { return }
            paginationState = .failed(.transport)
        }
    }
}
