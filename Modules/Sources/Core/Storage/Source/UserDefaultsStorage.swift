import Foundation
import StorageInterface

/// UserDefaults 기반 KeyValueStorage 구현.
///
/// `actor` 채택으로 protocol의 async 요구사항을 만족하지만,
/// 내부 mutable state가 없고 `UserDefaults` 자체가 thread-safe하므로
/// 모든 메서드를 `nonisolated`로 선언하여 actor hop을 회피한다.
/// (`InMemoryStorage`처럼 자체 상태를 가진 actor는 isolated가 정상.)
public actor UserDefaultsStorage: KeyValueStorageProtocol {

    // MARK: - Init

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public

    public nonisolated func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public nonisolated func setData(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public nonisolated func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
