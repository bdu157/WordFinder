import Foundation
import Observation

/// 단어 하나를 사전에서 찾아 상세 시트의 상태를 관리한다.
///
/// 네트워크도 UIKit 도 모른다. `DictionaryService` 너머의 가짜로 상태 전이를 전부 검증한다 —
/// 카메라의 `ScanViewModel` 과 같은 방식이다.
@MainActor
@Observable
final class WordLookupModel {
    enum State: Equatable {
        case loading
        case loaded(DictEntry)
        /// 온라인 사전을 쓸 수 없어 Apple 내장 사전으로 넘긴 상태.
        case fallback(DictionaryError)
    }

    /// 실패 시 Apple 사전 위에 띄우는 안내 (설계 문서 §7). 원인에 따라 사용자가 알아야 할 것이
    /// 달라서 두 가지로 나눈다. em dash 는 전달 과정에서 뭉개지지 않도록 코드 포인트로 적는다.
    static let notFoundNotice = "Not in the online dictionary \u{2014} showing the iOS Dictionary"
    static let unavailableNotice = "Online dictionary didn't respond \u{2014} showing the iOS Dictionary"

    let term: String
    private(set) var state: State = .loading
    private let service: DictionaryService

    init(term: String, service: DictionaryService) {
        self.term = term
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await service.lookUp(term))
        } catch let error as DictionaryError {
            state = .fallback(error)
        } catch {
            state = .fallback(.unavailable)
        }
    }

    var fallbackNotice: String? {
        guard case .fallback(let error) = state else { return nil }
        switch error {
        case .notFound: return Self.notFoundNotice
        case .unavailable: return Self.unavailableNotice
        }
    }
}
