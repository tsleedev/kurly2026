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

    func test_setData_그리고_data_동일값_반환() {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        let value = Data("hello".utf8)

        sut.setData(value, forKey: key)

        XCTAssertEqual(sut.data(forKey: key), value)
    }

    func test_removeObject_이후_nil_반환() {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        sut.setData(Data("hello".utf8), forKey: key)

        sut.removeObject(forKey: key)

        XCTAssertNil(sut.data(forKey: key))
    }

    func test_setData_nil_전달시_삭제됨() {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        sut.setData(Data("hello".utf8), forKey: key)

        sut.setData(nil, forKey: key)

        XCTAssertNil(sut.data(forKey: key))
    }

    func test_존재하지_않는_키_조회시_nil_반환() {
        guard let sut else { return XCTFail("sut not initialized") }
        XCTAssertNil(sut.data(forKey: "nonExistentKey"))
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

    func test_setData_그리고_data_동일값_반환() {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        let value = Data("hello".utf8)

        sut.setData(value, forKey: key)

        XCTAssertEqual(sut.data(forKey: key), value)
    }

    func test_removeObject_이후_nil_반환() {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        sut.setData(Data("hello".utf8), forKey: key)

        sut.removeObject(forKey: key)

        XCTAssertNil(sut.data(forKey: key))
    }

    func test_setData_nil_전달시_삭제됨() {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "testKey"
        sut.setData(Data("hello".utf8), forKey: key)

        sut.setData(nil, forKey: key)

        XCTAssertNil(sut.data(forKey: key))
    }

    func test_존재하지_않는_키_조회시_nil_반환() {
        guard let sut else { return XCTFail("sut not initialized") }
        XCTAssertNil(sut.data(forKey: "nonExistentKey"))
    }

    func test_동시_setData_데이터레이스_없음() async {
        guard let sut else { return XCTFail("sut not initialized") }
        let key = "concurrentKey"
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<iterations {
                group.addTask {
                    sut.setData(Data("\(index)".utf8), forKey: key)
                }
            }
        }

        // 모든 작업 완료 후 크래시 없이 값을 읽을 수 있어야 함
        _ = sut.data(forKey: key)
    }
}
