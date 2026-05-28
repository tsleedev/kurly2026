import XCTest
import SearchInterface
import SearchTesting
@testable import Search

final class AutoCompleteUseCaseTests: XCTestCase {

    // MARK: - prefix 매칭

    func test_suggestions_prefix에_매칭되는_키워드를_반환한다() {
        let keywords = [
            RecentKeyword(keyword: "swift", searchedAt: Date()),
            RecentKeyword(keyword: "swiftUI", searchedAt: Date()),
            RecentKeyword(keyword: "kotlin", searchedAt: Date()),
        ]
        let mockRepo = MockRecentKeywordRepository(initial: keywords)
        let sut = AutoCompleteUseCaseImpl(repository: mockRepo)

        let result = sut.suggestions(for: "swif")

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.keyword.lowercased().hasPrefix("swif") })
    }

    func test_suggestions_대소문자를_무시하고_매칭한다() {
        let keywords = [
            RecentKeyword(keyword: "Swift", searchedAt: Date()),
            RecentKeyword(keyword: "SWIFT", searchedAt: Date()),
        ]
        let mockRepo = MockRecentKeywordRepository(initial: keywords)
        let sut = AutoCompleteUseCaseImpl(repository: mockRepo)

        let result = sut.suggestions(for: "swift")

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - 매칭 없음

    func test_suggestions_매칭되는_항목이_없으면_빈_배열을_반환한다() {
        let keywords = [
            RecentKeyword(keyword: "kotlin", searchedAt: Date()),
        ]
        let mockRepo = MockRecentKeywordRepository(initial: keywords)
        let sut = AutoCompleteUseCaseImpl(repository: mockRepo)

        let result = sut.suggestions(for: "swift")

        XCTAssertEqual(result, [])
    }

    // MARK: - 빈/공백 prefix

    func test_suggestions_빈_prefix이면_빈_배열을_반환한다() {
        let keywords = [
            RecentKeyword(keyword: "swift", searchedAt: Date()),
        ]
        let mockRepo = MockRecentKeywordRepository(initial: keywords)
        let sut = AutoCompleteUseCaseImpl(repository: mockRepo)

        let result = sut.suggestions(for: "")

        XCTAssertEqual(result, [])
    }

    func test_suggestions_공백만_있는_prefix이면_빈_배열을_반환한다() {
        let keywords = [
            RecentKeyword(keyword: "swift", searchedAt: Date()),
        ]
        let mockRepo = MockRecentKeywordRepository(initial: keywords)
        let sut = AutoCompleteUseCaseImpl(repository: mockRepo)

        let result = sut.suggestions(for: "   ")

        XCTAssertEqual(result, [])
    }

    // MARK: - maxCount 제한

    func test_suggestions_maxCount를_초과하면_잘린다() {
        let keywords = (1...15).map {
            RecentKeyword(
                keyword: "swift\($0)",
                searchedAt: Date(timeIntervalSinceReferenceDate: Double($0))
            )
        }
        let mockRepo = MockRecentKeywordRepository(initial: keywords)
        let sut = AutoCompleteUseCaseImpl(repository: mockRepo, maxCount: 10)

        let result = sut.suggestions(for: "swift")

        XCTAssertEqual(result.count, 10)
    }

    func test_suggestions_maxCount가_1이면_1개만_반환한다() {
        let keywords = [
            RecentKeyword(keyword: "swift1", searchedAt: Date(timeIntervalSinceReferenceDate: 1)),
            RecentKeyword(keyword: "swift2", searchedAt: Date(timeIntervalSinceReferenceDate: 2)),
        ]
        let mockRepo = MockRecentKeywordRepository(initial: keywords)
        let sut = AutoCompleteUseCaseImpl(repository: mockRepo, maxCount: 1)

        let result = sut.suggestions(for: "swift")

        XCTAssertEqual(result.count, 1)
    }

    // MARK: - 최신순 정렬

    func test_suggestions_searchedAt_내림차순으로_정렬된다() {
        let older = RecentKeyword(keyword: "swift_old", searchedAt: Date(timeIntervalSinceReferenceDate: 0))
        let newer = RecentKeyword(keyword: "swift_new", searchedAt: Date(timeIntervalSinceReferenceDate: 100))
        let mockRepo = MockRecentKeywordRepository(initial: [older, newer])
        let sut = AutoCompleteUseCaseImpl(repository: mockRepo)

        let result = sut.suggestions(for: "swift")

        XCTAssertEqual(result[0].keyword, "swift_new")
        XCTAssertEqual(result[1].keyword, "swift_old")
    }
}
