import Foundation
import Testing
@testable import WordFinder

/// 3단계(히스토리)에서 이 JSON 이 기기에 저장된다. 계약에 항목이 늘어도 이미 저장된 옛 JSON 은
/// 읽혀야 하므로, `Meaning.synonyms` 가 없는 JSON 의 디코딩을 고정한다.
@Test func decodesJSONWithoutMeaningSynonyms() throws {
    let json = """
    {"term":"resilient","lang":"en","type":"word","phonetic":null,"audioUrl":null,
     "meanings":[{"partOfSpeech":"adjective","definitions":[{"definition":"elastic","example":null,"synonyms":null}]}],
     "source":"dictionaryapi","fetchedAt":1789993534}
    """
    let entry = try JSONDecoder().decode(DictEntry.self, from: Data(json.utf8))
    #expect(entry.meanings[0].synonyms == nil)
    #expect(entry.meanings[0].definitions[0].definition == "elastic")
}

@Test func roundTripsMeaningSynonyms() throws {
    let entry = DictEntry(
        term: "resilient", lang: "en", type: .word, phonetic: nil, audioUrl: nil,
        meanings: [DictEntry.Meaning(
            partOfSpeech: "adjective",
            definitions: [DictEntry.Definition(definition: "elastic", example: nil, synonyms: nil)],
            synonyms: ["flexible"]
        )],
        source: .dictionaryapi, fetchedAt: 1789993534
    )
    let decoded = try JSONDecoder().decode(DictEntry.self, from: JSONEncoder().encode(entry))
    #expect(decoded == entry)
}

@Test func mwLearnersEncodesToItsWireValue() throws {
    let data = try JSONEncoder().encode(DictEntry.DictSource.mwLearners)
    #expect(String(decoding: data, as: UTF8.self) == "\"mw-learners\"")
}
