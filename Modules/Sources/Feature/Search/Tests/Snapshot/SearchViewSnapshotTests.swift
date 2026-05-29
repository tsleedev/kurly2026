#if canImport(UIKit)
import XCTest
import SnapshotTesting
import SwiftUI
import ImageLoadingTesting
import SearchInterface
import SearchTesting
@testable import Search

@MainActor
final class SearchViewSnapshotTests: XCTestCase {

    /// iPhone 17 (393x852) 기준. 스타일 가이드 65라인 준수.
    private let layout: SwiftUISnapshotLayout = .device(config: .iPhone17)
    private let precision: Float = 0.99

    // MARK: - State.recent

    func test_빈_최근검색() async {
        let (viewModel, _) = makeViewModel(recentKeywords: [])
        await viewModel.onAppear()

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    func test_최근검색_N개() async {
        let (viewModel, _) = makeViewModel(recentKeywords: [
            Self.keyword("swift", at: 1_700_000_000),
            Self.keyword("kotlin", at: 1_699_900_000),
            Self.keyword("rust", at: 1_699_800_000),
        ])
        await viewModel.onAppear()

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    // MARK: - State.autocomplete

    func test_자동완성_결과있음() async {
        let (viewModel, clock) = makeViewModel(
            recentKeywords: [
                Self.keyword("swift", at: 1_700_000_000),
                Self.keyword("swiftui", at: 1_699_900_000),
            ],
            suggestions: [
                Self.keyword("swift", at: 1_700_000_000),
                Self.keyword("swiftui", at: 1_699_900_000),
            ]
        )
        viewModel.query = "swi"
        viewModel.onQueryChanged("swi")
        await clock.advance(by: .milliseconds(300))

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    func test_자동완성_빈_결과() async {
        let (viewModel, clock) = makeViewModel(
            recentKeywords: [Self.keyword("swift", at: 1_700_000_000)],
            suggestions: []
        )
        viewModel.query = "kot"
        viewModel.onQueryChanged("kot")
        await clock.advance(by: .milliseconds(300))

        assertSnapshot(
            of: hosted(viewModel),
            as: .image(precision: precision, layout: layout),
            record: false
        )
    }

    // MARK: - Helpers

    private func makeViewModel(
        recentKeywords: [RecentKeyword],
        suggestions: [RecentKeyword] = []
    ) -> (SearchViewModel, TestClock) {
        let recent = MockRecentKeywordUseCase(stubRecent: recentKeywords)
        let autoComplete = MockAutoCompleteUseCase(stubSuggestions: suggestions)
        let clock = TestClock()
        let viewModel = SearchViewModel(
            recentKeywordUseCase: recent,
            autoCompleteUseCase: autoComplete,
            // .recent / .autocomplete 스냅샷은 결과 화면 진입 경로가 없어 factory가 호출되지 않는다.
            // .results 상태 스냅샷은 SearchResultViewSnapshotTests가 별도로 커버.
            makeSearchResultViewModel: { _ in
                fatalError("이 스냅샷은 .results 상태를 사용하지 않음")
            },
            clock: clock
        )
        return (viewModel, clock)
    }

    private func hosted(_ viewModel: SearchViewModel) -> some View {
        NavigationStack {
            SearchView(viewModel: viewModel, imageLoader: MockImageLoader())
        }
    }

    private static func keyword(_ value: String, at: TimeInterval) -> RecentKeyword {
        RecentKeyword(keyword: value, searchedAt: Date(timeIntervalSince1970: at))
    }
}
#endif
