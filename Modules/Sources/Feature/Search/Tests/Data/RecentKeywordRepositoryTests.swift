import XCTest
import SearchInterface
import StorageInterface
import StorageTesting
@testable import Search

final class RecentKeywordRepositoryTests: XCTestCase {

    // MARK: - 빈 상태

    func test_all_초기상태는_빈_배열() async {
        let sut = RecentKeywordRepository(storage: InMemoryStorage())

        let result = await sut.all()

        XCTAssertEqual(result, [])
    }

    // MARK: - append

    func test_append_새_키워드는_저장된다() async {
        let sut = RecentKeywordRepository(storage: InMemoryStorage())
        let date = Date(timeIntervalSince1970: 1_000)

        await sut.append("swift", at: date)
        let result = await sut.all()

        XCTAssertEqual(result, [RecentKeyword(keyword: "swift", searchedAt: date)])
    }

    func test_append_여러_키워드는_최신이_앞에_쌓인다() async {
        let sut = RecentKeywordRepository(storage: InMemoryStorage())
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let t3 = Date(timeIntervalSince1970: 3_000)

        await sut.append("swift", at: t1)
        await sut.append("kotlin", at: t2)
        await sut.append("rust", at: t3)
        let result = await sut.all()

        XCTAssertEqual(result.map(\.keyword), ["rust", "kotlin", "swift"])
    }

    func test_append_동일한_키워드는_dedupe되고_searchedAt이_갱신된다() async {
        let sut = RecentKeywordRepository(storage: InMemoryStorage())
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let t3 = Date(timeIntervalSince1970: 3_000)

        await sut.append("swift", at: t1)
        await sut.append("kotlin", at: t2)
        await sut.append("swift", at: t3)
        let result = await sut.all()

        XCTAssertEqual(result.map(\.keyword), ["swift", "kotlin"])
        XCTAssertEqual(result.first?.searchedAt, t3)
    }

    // MARK: - remove

    func test_remove_지정한_키워드만_제거된다() async {
        let sut = RecentKeywordRepository(storage: InMemoryStorage())
        await sut.append("swift", at: Date(timeIntervalSince1970: 1_000))
        await sut.append("kotlin", at: Date(timeIntervalSince1970: 2_000))

        await sut.remove("swift")
        let result = await sut.all()

        XCTAssertEqual(result.map(\.keyword), ["kotlin"])
    }

    func test_remove_없는_키워드는_무시된다() async {
        let sut = RecentKeywordRepository(storage: InMemoryStorage())
        await sut.append("swift", at: Date(timeIntervalSince1970: 1_000))

        await sut.remove("missing")
        let result = await sut.all()

        XCTAssertEqual(result.map(\.keyword), ["swift"])
    }

    // MARK: - removeAll

    func test_removeAll_모든_키워드를_제거한다() async {
        let sut = RecentKeywordRepository(storage: InMemoryStorage())
        await sut.append("swift", at: Date(timeIntervalSince1970: 1_000))
        await sut.append("kotlin", at: Date(timeIntervalSince1970: 2_000))

        await sut.removeAll()
        let result = await sut.all()

        XCTAssertEqual(result, [])
    }

    // MARK: - 영속성

    func test_새_repository_인스턴스도_동일한_storage면_저장된_데이터를_읽는다() async {
        let storage = InMemoryStorage()
        let first = RecentKeywordRepository(storage: storage)
        await first.append("swift", at: Date(timeIntervalSince1970: 1_000))

        let second = RecentKeywordRepository(storage: storage)
        let result = await second.all()

        XCTAssertEqual(result.map(\.keyword), ["swift"])
    }

    func test_손상된_저장값은_빈_배열로_복구된다() async {
        let storage = InMemoryStorage()
        await storage.setData(Data("not json".utf8), forKey: "feature.search.recentKeywords.v1")
        let sut = RecentKeywordRepository(storage: storage)

        let result = await sut.all()

        XCTAssertEqual(result, [])
    }
}
