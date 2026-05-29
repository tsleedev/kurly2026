#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import SearchInterface

/// 검색 진입 화면. 최근 검색 키워드 리스트 + 검색 입력.
///
/// 본 PR은 최근 검색만 다룬다. 자동완성 UI/디바운스는 후속 PR에서 도입.
public struct SearchView: View {

    @State private var viewModel: SearchViewModel
    @State private var deleteTarget: RecentKeyword?
    @State private var showDeleteAllAlert = false

    public init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        contentList
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "저장소 검색")
            .onSubmit(of: .search) {
                Task { await viewModel.onSubmit() }
            }
            .task {
                await viewModel.onAppear()
            }
            .alert(
                "검색어를 삭제할까요?",
                isPresented: deleteTargetBinding,
                presenting: deleteTarget
            ) { target in
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    Task { await viewModel.onConfirmDelete(target.keyword) }
                }
            } message: { target in
                Text("'\(target.keyword)' 검색어가 최근 검색에서 사라집니다.")
            }
            .alert(
                "최근 검색을 전체 삭제할까요?",
                isPresented: $showDeleteAllAlert
            ) {
                Button("취소", role: .cancel) {}
                Button("전체 삭제", role: .destructive) {
                    Task { await viewModel.onConfirmDeleteAll() }
                }
            }
    }

    // MARK: - Sections

    @ViewBuilder
    private var contentList: some View {
        if viewModel.recentKeywords.isEmpty {
            ContentUnavailableView(
                "최근 검색이 없어요",
                systemImage: "magnifyingglass",
                description: Text("저장소를 검색해 보세요")
            )
        } else {
            List {
                Section {
                    ForEach(viewModel.recentKeywords, id: \.keyword) { keyword in
                        RecentKeywordRow(
                            keyword: keyword,
                            onTap: { Task { await viewModel.onTapRecent(keyword.keyword) } },
                            onTapDelete: { deleteTarget = keyword }
                        )
                    }
                } header: {
                    HStack {
                        Text("최근 검색")
                        Spacer()
                        Button("전체삭제") { showDeleteAllAlert = true }
                            .font(.footnote)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Bindings

    private var deleteTargetBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { isPresented in
                if !isPresented { deleteTarget = nil }
            }
        )
    }
}
#endif
