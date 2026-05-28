import XCTest
import StorageInterface
import StorageTesting
@testable import Storage

// MARK: - UserDefaultsStorageTests

final class UserDefaultsStorageTests: XCTestCase {

    private var suiteName: String = ""
    private var sut: UserDefaultsStorage?

    override func setUp() {
        super.setUp()
        suiteName = "kurly.storage.test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("UserDefaults suite '\(suiteName)' 생성 실패")
            return
        }
        sut = UserDefaultsStorage(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        sut = nil
        super.tearDown()
    }

    func test_setData_그리고_data_동일값_반환() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        let value = Data("hello".utf8)

        await sut.setData(value, forKey: key)

        let got = await sut.data(forKey: key)
        XCTAssertEqual(got, value)
    }

    func test_removeObject_이후_nil_반환() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        await sut.setData(Data("hello".utf8), forKey: key)

        await sut.removeObject(forKey: key)

        let got = await sut.data(forKey: key)
        XCTAssertNil(got)
    }

    func test_setData_nil_전달시_삭제됨() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        await sut.setData(Data("hello".utf8), forKey: key)

        await sut.setData(nil, forKey: key)

        let got = await sut.data(forKey: key)
        XCTAssertNil(got)
    }

    func test_존재하지_않는_키_조회시_nil_반환() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let got = await sut.data(forKey: "nonExistentKey")
        XCTAssertNil(got)
    }
}

// MARK: - InMemoryStorageTests

final class InMemoryStorageTests: XCTestCase {

    private var sut: InMemoryStorage?

    override func setUp() {
        super.setUp()
        sut = InMemoryStorage()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_setData_그리고_data_동일값_반환() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        let value = Data("hello".utf8)

        await sut.setData(value, forKey: key)

        let got = await sut.data(forKey: key)
        XCTAssertEqual(got, value)
    }

    func test_removeObject_이후_nil_반환() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        await sut.setData(Data("hello".utf8), forKey: key)

        await sut.removeObject(forKey: key)

        let got = await sut.data(forKey: key)
        XCTAssertNil(got)
    }

    func test_setData_nil_전달시_삭제됨() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        await sut.setData(Data("hello".utf8), forKey: key)

        await sut.setData(nil, forKey: key)

        let got = await sut.data(forKey: key)
        XCTAssertNil(got)
    }

    func test_존재하지_않는_키_조회시_nil_반환() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let got = await sut.data(forKey: "nonExistentKey")
        XCTAssertNil(got)
    }

    func test_동시_setData_무결성() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "concurrentKey"
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<iterations {
                group.addTask {
                    await sut.setData(Data("\(index)".utf8), forKey: key)
                }
            }
        }

        // 모든 작업 완료 후 크래시 없이 값을 읽을 수 있어야 함 (actor isolation으로 보장)
        let got = await sut.data(forKey: key)
        XCTAssertNotNil(got)
    }
}
