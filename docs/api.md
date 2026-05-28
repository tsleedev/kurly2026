# GitHub Search API

## 엔드포인트

```
GET https://api.github.com/search/repositories?q={keyword}&page={page}&per_page=30
```

### Headers

```
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2022-11-28
User-Agent: KurlyGitHubSearchApp
```

(인증 토큰 없이 호출 — 평가자 환경 셋업 부담 0)

## Response 매핑

| API 필드 | Entity |
|---|---|
| `total_count` | `SearchResult.totalCount` |
| `items[]` | `[RepositoryDTO]` → `[Repository]` |
| `items[].id` | `Repository.id` |
| `items[].name` | `Repository.name` |
| `items[].full_name` | `Repository.fullName` |
| `items[].description` | `Repository.description` |
| `items[].html_url` | `Repository.htmlURL` |
| `items[].owner.login` | `Owner.login` |
| `items[].owner.avatar_url` | `Owner.avatarURL` |

## 페이지네이션

- `per_page=30` (고정)
- `page=1..N`
- `hasNextPage = items.count < totalCount`

## 에러 매핑

| 응답 | NetworkError |
|---|---|
| URL 구성 실패 | `.invalidURL` |
| URLError (network) | `.transport` |
| 401/403 + `X-RateLimit-Remaining: 0` | `.rateLimited(retryAfter:)` |
| 기타 4xx/5xx | `.statusCode(Int)` |
| JSON decode 실패 | `.decoding` |

`Retry-After` 헤더가 있으면 초 단위로 파싱해서 `retryAfter`에 채움.

## Rate Limit

| 상태 | 한도 |
|---|---|
| 무인증 (전체 API) | 60 req / hour / IP |
| 무인증 (Search API) | 10 req / min / IP |

데모 중 rate limit이 잡히면 UI에 "잠시 후 다시 시도해주세요" + retry-after 카운트다운(있다면) 노출.

## 자동완성 정책

GitHub Search API에는 별도 `suggest` 엔드포인트가 없음.

→ 자동완성은 **로컬 최근 검색어에서 prefix 매칭**만 수행:
- 매 키 입력마다 API 호출은 rate limit 부담 (특히 search 10req/min)
- 평가자 의도도 "최근 검색어 자동완성" (예시 화면 참조)

## 참고

- API 공식 문서: https://docs.github.com/en/rest/search/search#search-repositories
- Rate limit: https://docs.github.com/en/rest/rate-limit
