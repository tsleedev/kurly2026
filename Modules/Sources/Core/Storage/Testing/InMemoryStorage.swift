import Foundation
import StorageInterface

/// 테스트 전용 인메모리 KeyValueStorage 구현.
///
/// actor로 선언하여 컴파일러 수준의 thread-safety를 보장한다.
/// NSLock + @unchecked Sendable 패턴이 불필요하다.
public actor InMemoryStorage: KeyValueStorageProtocol {

    // MARK: - Init

    private var store: [String: Data] = [:]

    public init() {}

    // MARK: - Public

    public func data(forKey key: String) -> Data? {
        store[key]
    }

    public func setData(_ data: Data?, forKey key: String) {
        if let data {
            store[key] = data
        } else {
            store.removeValue(forKey: key)
        }
    }

    public func removeObject(forKey key: String) {
        store.removeValue(forKey: key)
    }
}
