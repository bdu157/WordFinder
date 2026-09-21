import Foundation

/// dictionaryapi.dev 응답을 `DictEntry` 로 바꾼다.
///
/// 변환 규칙은 설계 문서 `2026-09-21-word-lookup-design.md` §6. 순수 함수라 네트워크 없이
/// 실제 응답 픽스처로 검증한다. 서버가 생기면 서버 쪽 구현이 같은 규칙을 따르면 화면이
/// 똑같이 보인다.
enum DictionaryAPIMapper {
    enum MappingError: Error, Equatable {
        /// 응답 배열이 비어 있다.
        case noEntries
    }

    static func map(_ data: Data, fetchedAt: Int) throws -> DictEntry {
        let entries = try JSONDecoder().decode([APIEntry].self, from: data)
        guard let first = entries.first else { throw MappingError.noEntries }

        return DictEntry(
            term: first.word,
            lang: "en",
            type: first.word.contains(" ") ? .phrase : .word,
            phonetic: phonetic(in: entries),
            audioUrl: audioURL(in: entries),
            meanings: mergedMeanings(from: entries),
            source: .dictionaryapi,
            fetchedAt: fetchedAt
        )
    }

    /// `phonetic` → `phonetics[].text` 순으로, 모든 항목을 통틀어 비어 있지 않은 첫 값.
    /// `resilient` 는 둘 다 없다.
    private static func phonetic(in entries: [APIEntry]) -> String? {
        entries
            .flatMap { [$0.phonetic] + ($0.phonetics ?? []).map(\.text) }
            .lazy.compactMap(nonEmpty).first
    }

    /// 비어 있지 않은 첫 `audio`. `running` 은 첫 항목의 `audio` 가 빈 문자열이고
    /// 두 번째 항목에만 URL 이 있어서, 없는 것뿐 아니라 빈 문자열도 건너뛰어야 한다.
    private static func audioURL(in entries: [APIEntry]) -> String? {
        entries
            .flatMap { ($0.phonetics ?? []).map(\.audio) }
            .lazy.compactMap(nonEmpty).first
    }

    /// 모든 항목의 뜻을 합치되 같은 품사는 하나로 묶는다. 품사는 처음 나온 순서를 유지한다.
    /// 동형이의어는 항목이 여러 개로 오는데, 화면에는 품사당 한 블록만 보여주기 위해서다.
    private static func mergedMeanings(from entries: [APIEntry]) -> [DictEntry.Meaning] {
        var order: [String] = []
        var definitions: [String: [DictEntry.Definition]] = [:]
        var synonyms: [String: [String]] = [:]

        for meaning in entries.flatMap(\.meanings) {
            let pos = meaning.partOfSpeech
            if definitions[pos] == nil {
                order.append(pos)
                definitions[pos] = []
                synonyms[pos] = []
            }
            definitions[pos]! += meaning.definitions.map {
                DictEntry.Definition(
                    definition: $0.definition,
                    example: nonEmpty($0.example),
                    synonyms: deduplicated($0.synonyms ?? [])
                )
            }
            synonyms[pos]! += meaning.synonyms ?? []
        }

        return order.map {
            DictEntry.Meaning(partOfSpeech: $0, definitions: definitions[$0]!, synonyms: deduplicated(synonyms[$0]!))
        }
    }

    /// 순서를 지키며 중복을 없앤다. 비면 `nil` — 화면이 빈 동의어 줄을 그리지 않도록.
    private static func deduplicated(_ values: [String]) -> [String]? {
        var seen = Set<String>()
        let unique = values.filter { !$0.isEmpty && seen.insert($0).inserted }
        return unique.isEmpty ? nil : unique
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    // MARK: - dictionaryapi.dev 응답 모양 (쓰는 필드만)

    private struct APIEntry: Decodable {
        let word: String
        let phonetic: String?
        let phonetics: [APIPhonetic]?
        let meanings: [APIMeaning]
    }

    private struct APIPhonetic: Decodable {
        let text: String?
        let audio: String?
    }

    private struct APIMeaning: Decodable {
        let partOfSpeech: String
        let definitions: [APIDefinition]
        let synonyms: [String]?
    }

    private struct APIDefinition: Decodable {
        let definition: String
        let example: String?
        let synonyms: [String]?
    }
}
