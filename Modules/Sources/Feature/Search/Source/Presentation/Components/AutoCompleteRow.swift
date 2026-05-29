#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import SearchInterface

/// 자동완성 row. 키워드 + 최근 검색 날짜 표시.
struct AutoCompleteRow: View {

    let keyword: RecentKeyword
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(keyword.keyword)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(Self.dateFormatter.string(from: keyword.searchedAt))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    /// "yyyy. MM. dd." 형식 (한국 컬리 앱 규약).
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd."
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
}
#endif
