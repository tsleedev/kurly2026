#if canImport(UIKit)
import XCTest
import SnapshotTesting
import SwiftUI
import SearchInterface
import SearchTesting
@testable import Search

@MainActor
final class SearchViewSnapshotTests: XCTestCase {

    /// iPhone 13 Pro 사이즈(390x844)로 고정. 실제 CI 시뮬레이터(iPhone 17)와 무관하게 결정론적.
    private let layout: SwiftUISnapshotLayout = .device(config: .iPhone13Pro)
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
            clock: clock
        )
        return (viewModel, clock)
    }

    private func hosted(_ viewModel: SearchViewModel) -> some View {
        NavigationStack {
            SearchView(viewModel: viewModel)
        }
    }

    private static func keyword(_ value: String, at: TimeInterval) -> RecentKeyword {
        RecentKeyword(keyword: value, searchedAt: Date(timeIntervalSince1970: at))
    }
}
#endif
