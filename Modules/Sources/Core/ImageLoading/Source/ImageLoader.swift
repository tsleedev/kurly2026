#if canImport(UIKit)
import UIKit
import ImageLoadingInterface

/// NSCache 기반 메모리 캐시 + 동일 URL 동시 요청 dedup을 제공하는 ImageLoader.
public actor ImageLoader: ImageLoaderProtocol {

    // MARK: - Private

    private let session: URLSession
    private let cache: NSCache<NSURL, UIImage>
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    // MARK: - Init

    public init(
        session: URLSession = .shared,
        cache: NSCache<NSURL, UIImage> = NSCache()
    ) {
        self.session = session
        self.cache = cache
    }

    // MARK: - Public

    public func image(for url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let task = inFlight[url] { return try await task.value }

        let task = Task<UIImage, Error> { [session, cache] in
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw ImageLoadingError.invalidResponse
            }
            guard let image = UIImage(data: data) else {
                throw ImageLoadingError.decodingFailed
            }
            cache.setObject(image, forKey: url as NSURL)
            return image
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        do {
            return try await task.value
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw ImageLoadingError.cancelled
            }
            throw error
        }
    }

    public func cancel(for url: URL) {
        inFlight[url]?.cancel()
        inFlight[url] = nil
    }
}
#endif
