#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import ImageLoadingInterface
import NetworkInterface
import SearchInterface

/// 검색 결과 화면. 본 PR은 page=1만 보여준다.
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
            .navigationTitle(viewModel.query)
            .navigationBarTitleDisplayMode(.inline)
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
                    }
                } header: {
                    Text("\(formatted(result.totalCount))개 저장소")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
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
#endif
