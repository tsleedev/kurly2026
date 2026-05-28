import Foundation

/// Key-Value 저장소의 공용 인터페이스.
/// 최근 검색어(JSON Codable) 저장 등에 활용 예정.
///
/// 모든 메서드가 async로 정의되어 있으므로 구현체는 actor를 채택할 수 있다.
/// 이를 통해 NSLock + @unchecked Sendable 패턴 없이 컴파일러 수준의 thread-safety를 얻는다.
public protocol KeyValueStorageProtocol: Sendable {
    func data(forKey key: String) async -> Data?

    /// nil 전달 시 해당 키를 삭제한다.
    func setData(_ data: Data?, forKey key: String) async

    func removeObject(forKey key: String) async
}
