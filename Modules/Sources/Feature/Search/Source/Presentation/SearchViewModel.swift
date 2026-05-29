import Foundation
import Observation
import SearchInterface

/// 검색 진입 화면(SearchView) ViewModel.
///
/// 본 PR은 "최근 검색" 상태만 다룬다. 자동완성 상태/디바운스는 후속 PR(feat/auto-complete)에서
/// State enum과 함께 도입한다.
///
/// Router는 closure(`onRequestSearch`)로 위임받아 ViewModel이 AppRouter 타입을 모르게 한다.
@MainActor
@Observable
public final class SearchViewModel {

    // MARK: - State

    /// 최근 검색 키워드 (최신순).
    public private(set) var recentKeywords: [RecentKeyword] = []

    /// `.searchable`과 양방향 바인딩되는 검색어.
    public var query: String = ""

    // MARK: - Router seam

    /// 검색 트리거 시 호출되는 closure. AppRouter가 주입.
    public var onRequestSearch: ((String) -> Void)?

    // MARK: - Dependencies

    private let recentKeywordUseCase: RecentKeywordUseCase

    // MARK: - Init

    public init(recentKeywordUseCase: RecentKeywordUseCase) {
        self.recentKeywordUseCase = recentKeywordUseCase
    }

    // MARK: - Lifecycle

    public func onAppear() async {
        recentKeywords = await recentKeywordUseCase.recent()
    }

    // MARK: - User actions

    public func onSubmit() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        query = trimmed
        await recentKeywordUseCase.save(trimmed)
        recentKeywords = await recentKeywordUseCase.recent()
        onRequestSearch?(trimmed)
    }

    public func onTapRecent(_ keyword: String) async {
        query = keyword
        await recentKeywordUseCase.save(keyword)
        recentKeywords = await recentKeywordUseCase.recent()
        onRequestSearch?(keyword)
    }

    public func onConfirmDelete(_ keyword: String) async {
        await recentKeywordUseCase.delete(keyword)
        recentKeywords = await recentKeywordUseCase.recent()
    }

    public func onConfirmDeleteAll() async {
        await recentKeywordUseCase.deleteAll()
        recentKeywords = []
    }
}
