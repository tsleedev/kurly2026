import Foundation
import StorageInterface

/// UserDefaults 기반 KeyValueStorage 구현.
///
/// actor로 선언하여 protocol의 async 메서드와 일치시킨다.
/// UserDefaults 자체가 thread-safe하지만 protocol이 actor isolated이므로
/// actor 채택으로 @unchecked Sendable 없이 컴파일러 보장을 받는다.
public actor UserDefaultsStorage: KeyValueStorageProtocol {

    // MARK: - Init

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func setData(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
