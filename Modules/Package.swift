// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Modules",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Public products = App이 쓸 수 있는 것만 노출.
        // *Testing 타겟은 product로 노출하지 않음 — 같은 패키지 내 testTarget이
        // targets 배열의 이름으로 직접 의존 가능. 외부에 Mock 유출 방지.
        .library(name: "SearchInterface", targets: ["SearchInterface"]),
        .library(name: "Search", targets: ["Search"]),

        .library(name: "WebViewInterface", targets: ["WebViewInterface"]),
        .library(name: "WebView", targets: ["WebView"]),

        .library(name: "NetworkInterface", targets: ["NetworkInterface"]),
        .library(name: "Network", targets: ["Network"]),

        .library(name: "StorageInterface", targets: ["StorageInterface"]),
        .library(name: "Storage", targets: ["Storage"]),

        .library(name: "ImageLoadingInterface", targets: ["ImageLoadingInterface"]),
        .library(name: "ImageLoading", targets: ["ImageLoading"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
    ],
    targets: [
        // MARK: Search
        .target(name: "SearchInterface", path: "Sources/Feature/Search/Interface"),
        .target(
            name: "Search",
            dependencies: [
                "SearchInterface",
                "NetworkInterface",
                "StorageInterface",
                "ImageLoadingInterface",
                // CachedAsyncImage(공용 SwiftUI 컴포넌트) 사용. Source-to-Source 의존은
                // architecture.md의 Interface-only 원칙에서 벗어나는 예외 — 공용 UI 컴포넌트의
                // 중복 구현을 피하기 위한 의도적 선택. 향후 ImageLoadingComponents 같은
                // 별도 UI 모듈로 분리 검토.
                "ImageLoading",
            ],
            path: "Sources/Feature/Search/Source",
            swiftSettings: [
                // SwiftPM target 은 Xcode App target 과 달리 DEBUG flag 가 자동 설정되지 않는다.
                // SwiftUI #Preview 와 PreviewSupport.swift 의 #if DEBUG 가드가 작동하도록 명시적으로 정의.
                .define("DEBUG", .when(configuration: .debug)),
            ]
        ),
        .target(
            name: "SearchTesting",
            dependencies: ["SearchInterface"],
            path: "Sources/Feature/Search/Testing"
        ),
        .testTarget(
            name: "SearchTests",
            dependencies: [
                "Search",
                "SearchTesting",
                "NetworkTesting",
                "StorageTesting",
                "ImageLoadingTesting",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Sources/Feature/Search/Tests"
        ),

        // MARK: WebView
        .target(name: "WebViewInterface", path: "Sources/Feature/WebView/Interface"),
        .target(
            name: "WebView",
            dependencies: ["WebViewInterface"],
            path: "Sources/Feature/WebView/Source"
        ),
        .testTarget(
            name: "WebViewTests",
            dependencies: [
                "WebView",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Sources/Feature/WebView/Tests"
        ),

        // MARK: Core/Network
        .target(name: "NetworkInterface", path: "Sources/Core/Network/Interface"),
        .target(
            name: "Network",
            dependencies: ["NetworkInterface"],
            path: "Sources/Core/Network/Source"
        ),
        .target(
            name: "NetworkTesting",
            dependencies: ["NetworkInterface"],
            path: "Sources/Core/Network/Testing"
        ),
        .testTarget(
            name: "NetworkTests",
            dependencies: ["Network", "NetworkTesting"],
            path: "Sources/Core/Network/Tests"
        ),

        // MARK: Core/Storage
        .target(name: "StorageInterface", path: "Sources/Core/Storage/Interface"),
        .target(
            name: "Storage",
            dependencies: ["StorageInterface"],
            path: "Sources/Core/Storage/Source"
        ),
        .target(
            name: "StorageTesting",
            dependencies: ["StorageInterface"],
            path: "Sources/Core/Storage/Testing"
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage", "StorageTesting"],
            path: "Sources/Core/Storage/Tests"
        ),

        // MARK: Core/ImageLoading
        .target(name: "ImageLoadingInterface", path: "Sources/Core/ImageLoading/Interface"),
        .target(
            name: "ImageLoading",
            dependencies: ["ImageLoadingInterface"],
            path: "Sources/Core/ImageLoading/Source"
        ),
        .target(
            name: "ImageLoadingTesting",
            dependencies: ["ImageLoadingInterface"],
            path: "Sources/Core/ImageLoading/Testing"
        ),
        .testTarget(
            name: "ImageLoadingTests",
            dependencies: ["ImageLoading", "ImageLoadingTesting"],
            path: "Sources/Core/ImageLoading/Tests"
        ),
    ]
)
