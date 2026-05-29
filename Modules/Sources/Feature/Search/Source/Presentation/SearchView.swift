#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import ImageLoadingInterface
import SearchInterface

/// 검색 진입 화면. ViewModel.state로부터 세 가지 화면을 분기:
/// `.recent` 최근 검색 / `.autocomplete` 자동완성 / `.results` 검색 결과(같은 화면 내 nested).
///
/// 결과는 별도 push가 아니라 본 View 내부에서 그려지므로 `.navigationTitle("Search")`와
/// `.searchable`이 그대로 유지된다 — 예시 화면(`예시 2..png`)과 동일한 시각 효과
/// (large title이 결과 스크롤에 따라 collapse, "취소" 버튼이 검색바 옆에 유지).
public struct SearchView: View {

    public let viewModel: SearchViewModel
    public let imageLoader: any ImageLoaderProtocol
    @State private var deleteTarget: RecentKeyword?
    @State private var showDeleteAllAlert = false

    public init(viewModel: SearchViewModel, imageLoader: any ImageLoaderProtocol) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
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
        case .results(let resultViewModel):
            SearchResultView(viewModel: resultViewModel, imageLoader: imageLoader)
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

#if DEBUG
#Preview("최근 검색 - 빈") {
    NavigationStack {
        SearchView(
            viewModel: SearchViewModel(
                recentKeywordUseCase: StubRecentKeywordUseCase([]),
                autoCompleteUseCase: StubAutoCompleteUseCase([]),
                makeSearchResultViewModel: previewMakeSearchResultViewModel
            ),
            imageLoader: StubImageLoader()
        )
    }
}

#Preview("최근 검색 - 데이터 있음") {
    NavigationStack {
        SearchView(
            viewModel: SearchViewModel(
                recentKeywordUseCase: StubRecentKeywordUseCase(PreviewFixture.recentKeywords),
                autoCompleteUseCase: StubAutoCompleteUseCase([]),
                makeSearchResultViewModel: previewMakeSearchResultViewModel
            ),
            imageLoader: StubImageLoader()
        )
    }
}

#Preview("자동완성 - 결과 있음") {
    let viewModel = SearchViewModel(
        recentKeywordUseCase: StubRecentKeywordUseCase(PreviewFixture.recentKeywords),
        autoCompleteUseCase: StubAutoCompleteUseCase(PreviewFixture.recentKeywords),
        makeSearchResultViewModel: previewMakeSearchResultViewModel,
        clock: ContinuousClock(),
        debounceDuration: .zero
    )
    return NavigationStack {
        SearchView(viewModel: viewModel, imageLoader: StubImageLoader())
            .onAppear {
                viewModel.query = "swi"
                viewModel.onQueryChanged("swi")
            }
    }
}

#Preview("자동완성 - 결과 없음") {
    let viewModel = SearchViewModel(
        recentKeywordUseCase: StubRecentKeywordUseCase(PreviewFixture.recentKeywords),
        autoCompleteUseCase: StubAutoCompleteUseCase([]),
        makeSearchResultViewModel: previewMakeSearchResultViewModel,
        clock: ContinuousClock(),
        debounceDuration: .zero
    )
    return NavigationStack {
        SearchView(viewModel: viewModel, imageLoader: StubImageLoader())
            .onAppear {
                viewModel.query = "kot"
                viewModel.onQueryChanged("kot")
            }
    }
}
#endif
#endif
