import Foundation

/// Placeholder content for the camera scan flow until OCR + dictionary lookup
/// (Week 0 PoC, see PLAN.md §2/§8) are wired up. Mirrors the mock copy used in
/// the Claude Design mockups so the UI can be built and reviewed before the
/// real pipeline exists.
struct ScannedWord: Identifiable, Equatable {
    let id = UUID()
    let term: String

    /// `id` 는 인스턴스마다 다르므로 단어 자체로 비교한다.
    static func == (lhs: ScannedWord, rhs: ScannedWord) -> Bool {
        lhs.term == rhs.term
    }
}

struct WordDetailPreview {
    let term: String
    let phonetic: String
    let partOfSpeech: String
    let definitions: [DefinitionPreview]
    let synonyms: [String]
    let capturedContext: String
    let highlightedTerm: String
    let source: String
}

struct DefinitionPreview: Identifiable {
    let id = UUID()
    let text: String
    let example: String?
}

enum CameraMock {
    static let recognizedWords = [
        ScannedWord(term: "resilient"),
        ScannedWord(term: "urban"),
        ScannedWord(term: "absorb"),
        ScannedWord(term: "shocks"),
    ]

    static let detail = WordDetailPreview(
        term: "resilient",
        phonetic: "/rɪˈzɪliənt/",
        partOfSpeech: "adjective",
        definitions: [
            DefinitionPreview(
                text: "able to become strong, healthy, or successful again after something bad happens",
                example: "The economy proved surprisingly resilient after the crisis."
            ),
            DefinitionPreview(
                text: "able to return to an original shape after being pressed or bent",
                example: nil
            ),
        ],
        synonyms: [],
        capturedContext: "Urban systems must be resilient enough to absorb shocks without collapse.",
        highlightedTerm: "resilient",
        source: "dictionaryapi.dev"
    )
}
