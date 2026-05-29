#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
import ImageLoading
import ImageLoadingInterface
import SearchInterface

/// 검색 결과 한 행: 좌측 owner avatar(원형) + 이름 + owner.login.
struct RepositoryRow: View {

    let repository: Repository
    let imageLoader: any ImageLoaderProtocol

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(
                url: repository.owner.avatarURL,
                loader: imageLoader,
                content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                },
                placeholder: {
                    Color(uiColor: .systemGray5)
                }
            )
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(repository.owner.login)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    List {
        ForEach(PreviewFixture.repositories) { repository in
            RepositoryRow(repository: repository, imageLoader: StubImageLoader())
        }
    }
    .listStyle(.plain)
}
#endif
#endif
