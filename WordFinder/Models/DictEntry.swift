import Foundation

/// Mirrors the server-side `DictEntry` contract defined in Cloud Functions (see PLAN.md §5).
/// This is the shared schema between client and server — keep it in sync with the OpenAPI spec.
struct DictEntry: Codable, Equatable {
    let term: String
    let lang: String
    let type: EntryType
    let phonetic: String?
    let audioUrl: String?
    let meanings: [Meaning]
    let source: DictSource
    /// 사전에서 가져온 시각. 1970-01-01 UTC 기준 **초** 단위.
    let fetchedAt: Int

    struct Meaning: Codable, Equatable {
        /// `meanings` 안에서 **한 번씩만** 나온다 — 같은 품사는 하나의 Meaning 으로 합쳐서 보낸다.
        /// 화면(`WordDetailSheet`)이 이 값을 식별자로 쓰므로, 중복되면 블록이 잘못 그려지고
        /// "Show all" 이 두 블록을 함께 펼친다. dictionaryapi.dev 변환은 `DictionaryAPIMapper` 가 보장한다.
        let partOfSpeech: String
        let definitions: [Definition]
        /// 품사 단위 동의어. dictionaryapi.dev 는 동의어를 대부분 뜻이 아니라 여기에 둔다.
        /// 선택 항목이라 이 필드가 없는 JSON — 기기에 이미 저장된 것 포함 — 도 그대로 읽힌다.
        let synonyms: [String]?
    }

    struct Definition: Codable, Equatable {
        let definition: String
        let example: String?
        let synonyms: [String]?
    }

    enum EntryType: String, Codable {
        case word
        case phrase
    }

    enum DictSource: String, Codable {
        case dictionaryapi
        case mwLearners = "mw-learners"
        case oxford
    }
}
