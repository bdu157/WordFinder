import Foundation

/// Mirrors the server-side `DictEntry` contract defined in Cloud Functions (see PLAN.md §5).
/// This is the shared schema between client and server — keep it in sync with the OpenAPI spec.
struct DictEntry: Codable {
    let term: String
    let lang: String
    let type: EntryType
    let phonetic: String?
    let audioUrl: String?
    let meanings: [Meaning]
    let source: DictSource
    let fetchedAt: Int

    struct Meaning: Codable {
        let partOfSpeech: String
        let definitions: [Definition]
    }

    struct Definition: Codable {
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
