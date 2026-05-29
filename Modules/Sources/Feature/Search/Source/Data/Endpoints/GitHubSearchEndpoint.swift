import Foundation
import NetworkInterface

/// GitHub Search API endpoint 정의.
///
/// docs/api.md 명세를 그대로 옮긴 값. base URL과 헤더는 Feature가 소유한다 —
/// Network 모듈은 transport(HTTP)만 알고 GitHub 도메인은 모르도록 책임을 분리한다.
enum GitHubSearchEndpoint {

    private static let baseURL = URL(string: "https://api.github.com")!

    private static let defaultHeaders: [String: String] = [
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "KurlyGitHubSearchApp",
    ]

    /// `GET /search/repositories?q={query}&page={page}&per_page=30`
    static func searchRepositories(query: String, page: Int, perPage: Int) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "/search/repositories",
            method: .get,
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage)),
            ],
            headers: defaultHeaders
        )
    }
}
