import Foundation
import Observation
import NetworkInterface
import SearchInterface

/// 검색 결과 화면 ViewModel.
///
/// 본 PR은 page=1만 로드한다. 무한 스크롤은 후속 PR(feat/infinite-scroll)에서 도입.
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

    public private(set) var state: State = .loading

    public let query: String

    // MARK: - Router seam

    /// 결과 셀 탭 시 호출. AppDIContainer가 closure로 주입해 WebViewDestination 변환을 담당.
    public var onRequestWebView: ((Repository) -> Void)?

    // MARK: - Dependencies

    private let searchUseCase: SearchRepositoriesUseCase
    @ObservationIgnored private var generation: UInt64 = 0

    // MARK: - Init

    public init(
        query: String,
        searchUseCase: SearchRepositoriesUseCase
    ) {
        self.query = query
        self.searchUseCase = searchUseCase
    }

    // MARK: - Lifecycle

    public func onAppear() async {
        // 첫 진입 또는 .task 재실행: 이미 .loaded 상태면 다시 로드하지 않는다.
        if case .loaded = state { return }
        await load()
    }

    // MARK: - User actions

    public func onRetry() async {
        await load()
    }

    public func onTapRepository(_ repository: Repository) {
        onRequestWebView?(repository)
    }

    // MARK: - Private

    private func load() async {
        generation &+= 1
        let requested = generation
        state = .loading
        do {
            let result = try await searchUseCase.execute(query: query, page: 1)
            guard requested == generation else { return }
            state = .loaded(result)
        } catch is CancellationError {
            // .task가 view 사라짐으로 인해 취소된 경우 — 사용자에게 에러를 보여주지 않는다.
            return
        } catch NetworkError.cancelled {
            return
        } catch let error as NetworkError {
            guard requested == generation else { return }
            state = .failed(error)
        } catch {
            guard requested == generation else { return }
            state = .failed(.transport)
        }
    }
}
