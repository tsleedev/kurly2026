import Foundation

/// 테스트용 결정론적 시계.
///
/// `sleep(until:tolerance:)`은 `advance(by:)`가 호출되어 deadline을 넘길 때까지 비동기로 대기한다.
/// `advance(by:)` 호출 직후 깨어난 sleepers의 후속 await가 실행될 수 있도록 yield한다.
///
/// 외부 라이브러리 0 정책에 따라 swift-clocks의 TestClock에 의존하지 않고 직접 구현.
public final class TestClock: Clock, @unchecked Sendable {

    // MARK: - Instant

    public struct Instant: InstantProtocol {
        public var offset: Duration

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }

        public func advanced(by duration: Duration) -> Self {
            Self(offset: offset + duration)
        }

        public func duration(to other: Self) -> Duration {
            other.offset - offset
        }
    }

    // MARK: - Sleeper

    private struct Sleeper {
        let id: UInt64
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    // MARK: - State

    private let lock = NSLock()
    private var _now = Instant(offset: .zero)
    private var sleepers: [Sleeper] = []
    private var nextSleeperID: UInt64 = 0

    // MARK: - Init

    public init() {}

    // MARK: - Clock

    public var now: Instant {
        lock.withLock { _now }
    }

    public var minimumResolution: Duration { .zero }

    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let sleeperID: UInt64 = lock.withLock {
            nextSleeperID += 1
            return nextSleeperID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                enum Action { case resume, cancel, register }
                // Task가 이미 취소된 상태에서 sleep이 호출되면 withTaskCancellationHandler가
                // onCancel을 즉시(또는 동시에) 부르는데, 이 시점에 sleeper가 아직 sleepers에 없으면
                // onCancel은 no-op이 되고 이후 등록된 sleeper는 영원히 깨어나지 못한다.
                // 이를 막기 위해 락 안에서 Task.isCancelled를 확인하고 즉시 cancel로 종결한다.
                let action: Action = lock.withLock {
                    if Task.isCancelled { return .cancel }
                    if _now >= deadline { return .resume }
                    sleepers.append(Sleeper(id: sleeperID, deadline: deadline, continuation: continuation))
                    return .register
                }
                switch action {
                case .resume: continuation.resume()
                case .cancel: continuation.resume(throwing: CancellationError())
                case .register: break
                }
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            let cancelled: CheckedContinuation<Void, Error>? = self.lock.withLock {
                guard let index = self.sleepers.firstIndex(where: { $0.id == sleeperID }) else {
                    return nil
                }
                return self.sleepers.remove(at: index).continuation
            }
            cancelled?.resume(throwing: CancellationError())
        }
    }

    // MARK: - Test Helpers

    /// 시계를 `duration`만큼 진행시키고, deadline을 넘긴 sleepers를 모두 깨운다.
    /// 깨어난 task들이 후속 await를 실행할 수 있도록 여러 번 yield한다.
    public func advance(by duration: Duration) async {
        let toResume: [CheckedContinuation<Void, Error>] = lock.withLock {
            _now = _now.advanced(by: duration)
            let ready = sleepers.filter { $0.deadline <= _now }
            sleepers.removeAll { $0.deadline <= _now }
            return ready.map(\.continuation)
        }
        for continuation in toResume {
            continuation.resume()
        }
        // 깨어난 task가 후속 await chain(actor hop 포함)을 진행할 시간 확보.
        // 단일 actor hop은 보통 1~2 yield면 충분하지만, MainActor + 다른 actor 사이에 더 많은 hop이
        // 끼어들 수 있어 여유 있게 반복한다. CI 슬로우 러너에서 flakiness 방지.
        for _ in 0..<30 {
            await Task.yield()
        }
    }
}
