#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import ImageLoadingInterface

/// 외부 ImageLoaderProtocol 을 통해 이미지를 비동기로 로드하는 SwiftUI View.
/// URL 이 변경되면 `.task(id:)` 가 자동으로 이전 Task 를 취소하고 새 로드를 시작한다.
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    public let url: URL
    public let loader: any ImageLoaderProtocol
    @ViewBuilder public let content: (Image) -> Content
    @ViewBuilder public let placeholder: () -> Placeholder

    @State private var image: UIImage?

    // MARK: - Init

    public init(
        url: URL,
        loader: any ImageLoaderProtocol,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.loader = loader
        self.content = content
        self.placeholder = placeholder
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) { [loader, url] in
            image = nil    // 새 URL 로드 시작 시 placeholder가 보이도록 초기화
            image = try? await withTaskCancellationHandler {
                try await loader.image(for: url)
            } onCancel: {
                Task { await loader.cancel(for: url) }
            }
        }
    }
}
#endif
