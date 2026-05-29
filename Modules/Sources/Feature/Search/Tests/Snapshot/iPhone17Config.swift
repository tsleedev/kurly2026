#if canImport(UIKit)
import UIKit
import SnapshotTesting

/// iPhone 17 (6.1") 기준 스냅샷 설정.
///
/// 393 × 852 logical points, Dynamic Island safe area top 59pt, home indicator bottom 34pt.
/// Plan/Style guide 기준: 모든 SwiftUI snapshot은 iPhone 17 / iOS latest로 통일.
extension ViewImageConfig {
    static let iPhone17 = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 393, height: 852),
        traits: UITraitCollection(traitsFrom: [
            UITraitCollection(displayScale: 3),
            UITraitCollection(userInterfaceIdiom: .phone),
            UITraitCollection(horizontalSizeClass: .compact),
            UITraitCollection(verticalSizeClass: .regular),
        ])
    )
}
#endif
