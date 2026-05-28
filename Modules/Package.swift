// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Modules",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SearchInterface", targets: ["SearchInterface"]),
        .library(name: "Search", targets: ["Search"]),
        .library(name: "SearchTesting", targets: ["SearchTesting"]),

        .library(name: "WebViewInterface", targets: ["WebViewInterface"]),
        .library(name: "WebView", targets: ["WebView"]),
        .library(name: "WebViewTesting", targets: ["WebViewTesting"]),

        .library(name: "NetworkInterface", targets: ["NetworkInterface"]),
        .library(name: "Network", targets: ["Network"]),
        .library(name: "NetworkTesting", targets: ["NetworkTesting"]),

        .library(name: "StorageInterface", targets: ["StorageInterface"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "StorageTesting", targets: ["StorageTesting"]),

        .library(name: "ImageLoadingInterface", targets: ["ImageLoadingInterface"]),
        .library(name: "ImageLoading", targets: ["ImageLoading"]),
        .library(name: "ImageLoadingTesting", targets: ["ImageLoadingTesting"]),
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
            ],
            path: "Sources/Feature/Search/Source"
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
        .target(
            name: "WebViewTesting",
            dependencies: ["WebViewInterface"],
            path: "Sources/Feature/WebView/Testing"
        ),
        .testTarget(
            name: "WebViewTests",
            dependencies: [
                "WebView",
                "WebViewTesting",
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
