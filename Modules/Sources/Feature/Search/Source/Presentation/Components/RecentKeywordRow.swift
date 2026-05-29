#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import SearchInterface

/// "최근 검색" 섹션의 한 row.
///
/// 키워드를 탭하면 onTap, X 버튼을 탭하면 onTapDelete가 호출된다.
struct RecentKeywordRow: View {

    let keyword: RecentKeyword
    let onTap: () -> Void
    let onTapDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onTap) {
                Text(keyword.keyword)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Button(action: onTapDelete) {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(keyword.keyword) 검색어 삭제")
        }
    }
}

#if DEBUG
#Preview {
    List {
        ForEach(PreviewFixture.recentKeywords, id: \.self) { keyword in
            RecentKeywordRow(keyword: keyword, onTap: {}, onTapDelete: {})
        }
    }
    .listStyle(.plain)
}
#endif

#endif
