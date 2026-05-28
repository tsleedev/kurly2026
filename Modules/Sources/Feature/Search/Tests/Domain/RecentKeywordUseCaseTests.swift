import XCTest
import SearchInterface
import SearchTesting
@testable import Search

final class RecentKeywordUseCaseTests: XCTestCase {

    // MARK: - save

    func test_save_trimmed된_keyword가_현재시간으로_append된다() {
        let fixedDate = Date(timeIntervalSinceReferenceDate: 0)
        let mockRepo = MockRecentKeywordRepository()
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo, clock: { fixedDate })

        sut.save("  swift  ")

        let all = mockRepo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].keyword, "swift")
        XCTAssertEqual(all[0].searchedAt, fixedDate)
    }

    func test_save_빈문자열이면_append를_호출하지_않는다() {
        let mockRepo = MockRecentKeywordRepository()
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo)

        sut.save("")

        XCTAssertEqual(mockRepo.all().count, 0)
    }

    func test_save_공백만_있는_문자열이면_append를_호출하지_않는다() {
        let mockRepo = MockRecentKeywordRepository()
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo)

        sut.save("   ")

        XCTAssertEqual(mockRepo.all().count, 0)
    }

    func test_save_clock_주입으로_시간이_deterministic하게_기록된다() {
        let t1 = Date(timeIntervalSinceReferenceDate: 100)
        let t2 = Date(timeIntervalSinceReferenceDate: 200)
        var callCount = 0
        let mockRepo = MockRecentKeywordRepository()
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo, clock: {
            callCount += 1
            return callCount == 1 ? t1 : t2
        })

        sut.save("swift")
        sut.save("kurly")

        let all = mockRepo.all()
        let swiftKeyword = all.first { $0.keyword == "swift" }
        let kurlyKeyword = all.first { $0.keyword == "kurly" }
        XCTAssertEqual(swiftKeyword?.searchedAt, t1)
        XCTAssertEqual(kurlyKeyword?.searchedAt, t2)
    }

    // MARK: - recent

    func test_recent_searchedAt_내림차순으로_정렬된다() {
        let older = RecentKeyword(keyword: "old", searchedAt: Date(timeIntervalSinceReferenceDate: 0))
        let newer = RecentKeyword(keyword: "new", searchedAt: Date(timeIntervalSinceReferenceDate: 100))
        let mockRepo = MockRecentKeywordRepository(initial: [older, newer])
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo)

        let result = sut.recent()

        XCTAssertEqual(result[0].keyword, "new")
        XCTAssertEqual(result[1].keyword, "old")
    }

    func test_recent_항목이_없으면_빈_배열을_반환한다() {
        let mockRepo = MockRecentKeywordRepository()
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo)

        XCTAssertEqual(sut.recent(), [])
    }

    // MARK: - delete

    func test_delete_해당_keyword가_repository에서_제거된다() {
        let keyword = RecentKeyword(keyword: "swift", searchedAt: Date())
        let mockRepo = MockRecentKeywordRepository(initial: [keyword])
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo)

        sut.delete("swift")

        XCTAssertEqual(mockRepo.all().count, 0)
    }

    func test_delete_다른_keyword는_남아있는다() {
        let k1 = RecentKeyword(keyword: "swift", searchedAt: Date(timeIntervalSinceReferenceDate: 0))
        let k2 = RecentKeyword(keyword: "kurly", searchedAt: Date(timeIntervalSinceReferenceDate: 1))
        let mockRepo = MockRecentKeywordRepository(initial: [k1, k2])
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo)

        sut.delete("swift")

        let remaining = mockRepo.all()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].keyword, "kurly")
    }

    // MARK: - deleteAll

    func test_deleteAll_모든_keyword가_제거된다() {
        let k1 = RecentKeyword(keyword: "swift", searchedAt: Date())
        let k2 = RecentKeyword(keyword: "kurly", searchedAt: Date())
        let mockRepo = MockRecentKeywordRepository(initial: [k1, k2])
        let sut = RecentKeywordUseCaseImpl(repository: mockRepo)

        sut.deleteAll()

        XCTAssertEqual(mockRepo.all().count, 0)
    }
}
