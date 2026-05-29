import XCTest
import SearchInterface
import SearchTesting
@testable import Search

@MainActor
final class SearchViewModelTests: XCTestCase {

    // MARK: - onAppear

    func test_onAppear_recentKeywords가_useCase에서_로드된다() async {
        let mock = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let sut = SearchViewModel(recentKeywordUseCase: mock)

        await sut.onAppear()

        XCTAssertEqual(sut.recentKeywords.map(\.keyword), ["swift"])
    }

    // MARK: - onSubmit

    func test_onSubmit_query가_비어있으면_save도_router_호출도_없다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = SearchViewModel(recentKeywordUseCase: mock)
        var requested: String?
        sut.onRequestSearch = { requested = $0 }
        sut.query = ""

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, [])
        XCTAssertNil(requested)
    }

    func test_onSubmit_query가_공백뿐이면_save도_router_호출도_없다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = SearchViewModel(recentKeywordUseCase: mock)
        var requested: String?
        sut.onRequestSearch = { requested = $0 }
        sut.query = "   "

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, [])
        XCTAssertNil(requested)
    }

    func test_onSubmit_query를_trim해서_save_하고_router를_호출한다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = SearchViewModel(recentKeywordUseCase: mock)
        var requested: String?
        sut.onRequestSearch = { requested = $0 }
        sut.query = "  swift  "

        await sut.onSubmit()

        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, ["swift"])
        XCTAssertEqual(requested, "swift")
    }

    func test_onSubmit_이후_recentKeywords가_갱신된다() async {
        let mock = MockRecentKeywordUseCase()
        let sut = SearchViewModel(recentKeywordUseCase: mock)
        sut.query = "swift"

        await mock.setStubRecent([Self.keyword("swift", at: 1)])
        await sut.onSubmit()

        XCTAssertEqual(sut.recentKeywords.map(\.keyword), ["swift"])
    }

    // MARK: - onTapRecent

    func test_onTapRecent_query_갱신_save_router_호출_recent_갱신() async {
        let mock = MockRecentKeywordUseCase()
        let sut = SearchViewModel(recentKeywordUseCase: mock)
        var requested: String?
        sut.onRequestSearch = { requested = $0 }

        await mock.setStubRecent([Self.keyword("kotlin", at: 2)])
        await sut.onTapRecent("kotlin")

        XCTAssertEqual(sut.query, "kotlin")
        let saves = await mock.capturedSaves
        XCTAssertEqual(saves, ["kotlin"])
        XCTAssertEqual(requested, "kotlin")
        XCTAssertEqual(sut.recentKeywords.map(\.keyword), ["kotlin"])
    }

    // MARK: - onConfirmDelete

    func test_onConfirmDelete_지정한_keyword를_삭제하고_recentKeywords를_갱신한다() async {
        let mock = MockRecentKeywordUseCase(stubRecent: [
            Self.keyword("swift", at: 1),
            Self.keyword("kotlin", at: 2),
        ])
        let sut = SearchViewModel(recentKeywordUseCase: mock)
        await sut.onAppear()

        await mock.setStubRecent([Self.keyword("kotlin", at: 2)])
        await sut.onConfirmDelete("swift")

        let deletes = await mock.capturedDeletes
        XCTAssertEqual(deletes, ["swift"])
        XCTAssertEqual(sut.recentKeywords.map(\.keyword), ["kotlin"])
    }

    // MARK: - onConfirmDeleteAll

    func test_onConfirmDeleteAll_deleteAll_호출_recentKeywords가_비워진다() async {
        let mock = MockRecentKeywordUseCase(stubRecent: [Self.keyword("swift", at: 1)])
        let sut = SearchViewModel(recentKeywordUseCase: mock)
        await sut.onAppear()

        await sut.onConfirmDeleteAll()

        let count = await mock.deleteAllCallCount
        XCTAssertEqual(count, 1)
        XCTAssertEqual(sut.recentKeywords, [])
    }

    // MARK: - Fixtures

    private static func keyword(_ value: String, at: TimeInterval) -> RecentKeyword {
        RecentKeyword(keyword: value, searchedAt: Date(timeIntervalSince1970: at))
    }
}
