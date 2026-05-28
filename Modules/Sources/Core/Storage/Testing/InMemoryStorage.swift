import Foundation
import StorageInterface

/// 테스트 전용 인메모리 KeyValueStorage 구현.
/// NSLock으로 동시 접근을 직렬화하므로 @unchecked Sendable 선언이 안전하다.
public final class InMemoryStorage: KeyValueStorageProtocol, @unchecked Sendable {

    // MARK: - Init

    private var store: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    // MARK: - Public

    public func data(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return store[key]
    }

    public func setData(_ data: Data?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        if let data {
            store[key] = data
        } else {
            store.removeValue(forKey: key)
        }
    }

    public func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        store.removeValue(forKey: key)
    }
}
