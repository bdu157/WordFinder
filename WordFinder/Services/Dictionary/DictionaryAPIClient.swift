import Foundation

/// `DictionaryService` 의 dictionaryapi.dev 구현.
///
/// 임시 구현이다. PLAN.md 는 서버가 앞에서 캐시하고 Merriam-Webster 로 폴백하는 구조를 정했고,
/// 서버가 생기면 이 타입은 교체된다. 2026-09-21 측정으로는 요청마다 약 20초가 걸리고 흔하지
/// 않은 단어는 HTTP 522 가 온다 (설계 문서 §2) — 그래서 3초 안에 못 받으면 포기하고,
/// 화면은 Apple 내장 사전으로 넘긴다.
struct DictionaryAPIClient: DictionaryService {
    /// 요청 전체 제한 시간 (설계 문서 §7).
    static let timeout: TimeInterval = 3

    /// 화면이 뜰 때마다 새 세션을 만들지 않도록 하나를 공유한다.
    static let shared = DictionaryAPIClient()

    private let session: URLSession

    init(session: URLSession = DictionaryAPIClient.makeSession()) {
        self.session = session
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        // timeoutIntervalForRequest 는 "데이터가 안 오는 공백" 기준이라, 조금씩 흘려보내는
        // 서버에서는 3초를 넘길 수 있다. 요청 전체 시간인 Resource 도 같은 값으로 묶는다.
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        return URLSession(configuration: configuration)
    }

    func lookUp(_ term: String) async throws -> DictEntry {
        // 경로 한 조각으로 넣으므로 "/" 도 인코딩한다 — "and/or" 가 경로를 나누지 않도록.
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            throw DictionaryError.notFound
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw DictionaryError.unavailable
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.interpret(status: status, data: data, fetchedAt: Int(Date().timeIntervalSince1970))
    }

    /// 상태 코드와 본문을 `DictEntry` 또는 `DictionaryError` 로 해석한다.
    /// 네트워크와 떼어 둔 순수 함수라 테스트에서 직접 부른다.
    /// 404 는 본문을 보지 않고 상태 코드만으로 판단한다.
    static func interpret(status: Int, data: Data, fetchedAt: Int) throws -> DictEntry {
        switch status {
        case 200:
            do {
                return try DictionaryAPIMapper.map(data, fetchedAt: fetchedAt)
            } catch {
                throw DictionaryError.unavailable
            }
        case 404:
            throw DictionaryError.notFound
        default:
            throw DictionaryError.unavailable
        }
    }
}
