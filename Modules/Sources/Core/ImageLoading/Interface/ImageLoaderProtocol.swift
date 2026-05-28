#if canImport(UIKit)
import UIKit

/// URL 로부터 UIImage를 비동기로 로드하는 추상 인터페이스.
public protocol ImageLoaderProtocol: Sendable {
    func image(for url: URL) async throws -> UIImage
    func cancel(for url: URL) async
}
#endif
