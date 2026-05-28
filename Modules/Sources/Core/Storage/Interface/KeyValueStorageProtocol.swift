import Foundation

/// Key-Value 저장소의 공용 인터페이스.
/// 최근 검색어(JSON Codable) 저장 등에 활용 예정.
public protocol KeyValueStorageProtocol: Sendable {
    func data(forKey key: String) -> Data?

    /// nil 전달 시 해당 키를 삭제한다.
    func setData(_ data: Data?, forKey key: String)

    func removeObject(forKey key: String)
}
