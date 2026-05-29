#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import SearchInterface

/// 검색 진입 화면. 두 가지 상태(.recent / .autocomplete)를 ViewModel.state로부터 분기.
///
/// 자동완성 진입/이탈은 ViewModel의 onQueryChanged 디바운스로 처리되며,
/// View는 상태 변화에 따라 섹션을 교체할 뿐 디바운스 타이밍을 알지 못한다.
public struct SearchView: View {

    public let viewModel: SearchViewModel
    @State private var deleteTarget: RecentKeyword?
    @State private var showDeleteAllAlert = false

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        contentList
            .navigationTitle("Search")
            .searchable(text: queryBinding, prompt: "저장소 검색")
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
        switch viewModel.state {
        case .recent(let items):
            recentSection(items: items)
        case .autocomplete(let items):
            autoCompleteSection(items: items)
        }
    }

    @ViewBuilder
    private func recentSection(items: [RecentKeyword]) -> some View {
        if items.isEmpty {
            ContentUnavailableView(
                "최근 검색이 없어요",
                systemImage: "magnifyingglass",
                description: Text("저장소를 검색해 보세요")
            )
        } else {
            List {
                Section {
                    ForEach(items, id: \.self) { keyword in
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

    @ViewBuilder
    private func autoCompleteSection(items: [RecentKeyword]) -> some View {
        if items.isEmpty {
            ContentUnavailableView(
                "일치하는 최근 검색이 없어요",
                systemImage: "text.magnifyingglass"
            )
        } else {
            List {
                ForEach(items, id: \.self) { keyword in
                    AutoCompleteRow(
                        keyword: keyword,
                        onTap: { Task { await viewModel.onTapRecent(keyword.keyword) } }
                    )
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Bindings

    /// `.searchable`용 binding. set에서 onQueryChanged를 호출해 **사용자 입력에서만** 디바운스를 트리거한다.
    /// 프로그램적으로 viewModel.query를 갱신(onSubmit, onTapRecent)할 때는 이 setter를 거치지 않으므로
    /// .onChange 피드백 루프로 .recent 상태가 클로버되는 문제를 차단한다.
    private var queryBinding: Binding<String> {
        Binding(
            get: { viewModel.query },
            set: { newValue in
                viewModel.query = newValue
                viewModel.onQueryChanged(newValue)
            }
        )
    }

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
