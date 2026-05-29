#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import ImageLoadingInterface
import NetworkInterface
import SearchInterface

/// 검색 결과 화면. 무한 스크롤로 페이지 누적.
///
/// SearchView 내부에 nested로 렌더되므로 자체적으로 navigation title을 설정하지 않는다.
/// 부모(SearchView)의 `.navigationTitle("Search")` + `.searchable`이 그대로 유지되어
/// large title이 결과 스크롤에 따라 collapse되는 동작을 자연스럽게 얻는다.
public struct SearchResultView: View {

    public let viewModel: SearchResultViewModel
    public let imageLoader: any ImageLoaderProtocol

    public init(
        viewModel: SearchResultViewModel,
        imageLoader: any ImageLoaderProtocol
    ) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
    }

    public var body: some View {
        content
            .task {
                await viewModel.onAppear()
            }
    }

    // MARK: - Sections

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let result):
            loadedList(result)
        case .failed(let error):
            errorView(error)
        }
    }

    @ViewBuilder
    private func loadedList(_ result: SearchResult) -> some View {
        if result.repositories.isEmpty {
            ContentUnavailableView(
                "검색 결과가 없어요",
                systemImage: "magnifyingglass",
                description: Text("'\(viewModel.query)'에 대한 저장소를 찾을 수 없습니다")
            )
        } else {
            List {
                Section {
                    ForEach(result.repositories) { repository in
                        Button {
                            viewModel.onTapRepository(repository)
                        } label: {
                            RepositoryRow(
                                repository: repository,
                                imageLoader: imageLoader
                            )
                        }
                        .buttonStyle(.borderless)
                        .onAppear {
                            // `.task(id:)`는 셀이 스크롤 밖으로 나가면 cancel되어 진행 중인 페이지 로드를 끊는다.
                            // 무한 스크롤에서는 사용자가 계속 스크롤하므로 cancel이 일상적 — unstructured Task로
                            // 셀 라이프사이클과 분리한다. 늦은 결과는 ViewModel의 generation 가드가 처리.
                            Task { await viewModel.loadNextPageIfNeeded(currentItem: repository) }
                        }
                    }
                } header: {
                    Text("\(formatted(result.totalCount))개 저장소")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if viewModel.paginationState != .idle {
                    Section {
                        paginationFooter
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        switch viewModel.paginationState {
        case .idle:
            EmptyView()
        case .loading:
            HStack {
                Spacer()
                ProgressView()
                    .padding(.vertical, 12)
                Spacer()
            }
            .listRowSeparator(.hidden)
        case .failed(let error):
            VStack(spacing: 8) {
                Text("다음 페이지를 불러오지 못했어요")
                    .font(.subheadline)
                Text(message(for: error))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("다시 시도") {
                    Task { await viewModel.retryNextPage() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private func errorView(_ error: NetworkError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("검색을 불러오지 못했어요")
                .font(.headline)
            Text(message(for: error))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await viewModel.onRetry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func formatted(_ value: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func message(for error: NetworkError) -> String {
        switch error {
        case .rateLimited:
            return "잠시 후 다시 시도해주세요"
        case .transport, .cancelled:
            return "네트워크 연결을 확인해주세요"
        case .invalidURL, .decoding, .statusCode:
            return "응답을 처리하지 못했어요. 잠시 후 다시 시도해주세요"
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        // groupingSeparator는 사용자 Locale을 따른다(한국 "," / 독일 "." / 프랑스 공백 등).
        return formatter
    }()
}

#if DEBUG
#Preview("loading") {
    NavigationStack {
        SearchResultView(
            viewModel: SearchResultViewModel(
                query: "swift",
                searchUseCase: StubSearchRepositoriesUseCase(.neverResolve)
            ),
            imageLoader: StubImageLoader()
        )
    }
}

#Preview("loaded - 저장소 N개") {
    NavigationStack {
        SearchResultView(
            viewModel: SearchResultViewModel(
                query: "swift",
                searchUseCase: StubSearchRepositoriesUseCase(.success(PreviewFixture.searchResult))
            ),
            imageLoader: StubImageLoader()
        )
    }
}

#Preview("loaded - 빈 결과") {
    NavigationStack {
        SearchResultView(
            viewModel: SearchResultViewModel(
                query: "swift",
                searchUseCase: StubSearchRepositoriesUseCase(.success(PreviewFixture.emptySearchResult))
            ),
            imageLoader: StubImageLoader()
        )
    }
}

#Preview("failed - rate limited") {
    NavigationStack {
        SearchResultView(
            viewModel: SearchResultViewModel(
                query: "swift",
                searchUseCase: StubSearchRepositoriesUseCase(.failure(.rateLimited(retryAfter: 30)))
            ),
            imageLoader: StubImageLoader()
        )
    }
}

#Preview("failed - transport") {
    NavigationStack {
        SearchResultView(
            viewModel: SearchResultViewModel(
                query: "swift",
                searchUseCase: StubSearchRepositoriesUseCase(.failure(.transport))
            ),
            imageLoader: StubImageLoader()
        )
    }
}
#endif
#endif
