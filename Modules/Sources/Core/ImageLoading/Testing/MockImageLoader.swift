#if canImport(UIKit)
import UIKit
import ImageLoadingInterface

/// 테스트에서 ImageLoaderProtocol 을 대체하는 Mock.
/// URL 별로 성공/실패 모드를 설정하고 호출 횟수를 기록한다.
public final class MockImageLoader: ImageLoaderProtocol, @unchecked Sendable {

    // MARK: - Mode

    public enum Mode {
        case success(UIImage)
        case failure(Error)
    }

    // MARK: - Private

    private let lock = NSLock()
    private var modeByURL: [URL: Mode] = [:]
    private var defaultMode: Mode
    private var _callCounts: [URL: Int] = [:]

    public var callCounts: [URL: Int] {
        lock.lock()
        defer { lock.unlock() }
        return _callCounts
    }

    // MARK: - Init

    public init(default mode: Mode = .success(UIImage())) {
        self.defaultMode = mode
    }

    // MARK: - Public

    public func setMode(_ mode: Mode, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        modeByURL[url] = mode
    }

    public func image(for url: URL) async throws -> UIImage {
        lock.lock()
        _callCounts[url, default: 0] += 1
        let mode = modeByURL[url] ?? defaultMode
        lock.unlock()
        switch mode {
        case .success(let image): return image
        case .failure(let error): throw error
        }
    }

    public func cancel(for url: URL) {}
}
#endif
