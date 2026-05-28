import Foundation
import StorageInterface

/// UserDefaults 기반 KeyValueStorage 구현.
/// UserDefaults는 내부적으로 thread-safe하므로 @unchecked Sendable 선언이 안전하다.
public final class UserDefaultsStorage: KeyValueStorageProtocol, @unchecked Sendable {

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
