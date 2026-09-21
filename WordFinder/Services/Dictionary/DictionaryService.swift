import Foundation

enum DictionaryError: Error, Equatable {
    /// 온라인 사전에 없는 단어 (HTTP 404).
    case notFound
    /// 응답이 없거나 늦거나 해석할 수 없다 — 3초 초과, 522, 5xx, 네트워크 끊김, 깨진 응답.
    case unavailable
}

/// 단어 하나의 사전 항목을 가져온다.
///
/// 프로토콜로 둔 이유: 지금은 앱이 dictionaryapi.dev 를 직접 부르지만, 서버(Cloud Functions)가
/// 생기면 구현체만 바꾸고 화면은 그대로 둔다. 테스트에서 가짜를 넣을 수 있는 것도 같은 이점이다.
protocol DictionaryService: Sendable {
    func lookUp(_ term: String) async throws -> DictEntry
}
