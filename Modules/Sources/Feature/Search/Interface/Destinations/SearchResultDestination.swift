import Foundation

/// 검색 결과 ViewModel(`SearchResultViewModel`) 생성에 필요한 파라미터를 묶은 값 객체.
///
/// 이전에는 AppRouter가 push할 destination 식별값이었으나, 검색 결과를 SearchView 내부 state로
/// 표시하도록 변경(`refactor/search-result-inline-state`)되면서 의미를 재정의했다.
/// 현재는 `SearchViewModel`이 보유한 factory closure(`makeSearchResultViewModel`)의 입력 타입으로 쓰인다.
///
/// Interface에 남겨두는 이유: 결과 화면 파라미터가 늘어나도(예: 정렬, 페이지 size) 본 struct만
/// 확장하면 되고, 호출 측(Composition Root)과 호출 받는 측(Search 모듈) 시그니처가 안정적으로 유지된다.
public struct SearchResultDestination: Hashable, Sendable {
    public let query: String

    public init(query: String) {
        self.query = query
    }
}
