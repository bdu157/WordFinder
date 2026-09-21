import Foundation
import Testing
@testable import WordFinder

/// `WordFinderTests/Fixtures/` 의 JSON 은 2026-09-21 에 dictionaryapi.dev 에서 실제로 받은 응답이다.
private func fixture(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

@Test func mapsResilientWhichHasNoPhoneticAndOnlyMeaningLevelSynonyms() throws {
    let entry = try DictionaryAPIMapper.map(fixture("dictionaryapi-resilient"), fetchedAt: 1789993534)

    #expect(entry.term == "resilient")
    #expect(entry.lang == "en")
    #expect(entry.type == .word)
    #expect(entry.source == .dictionaryapi)
    #expect(entry.fetchedAt == 1789993534)
    #expect(entry.phonetic == nil)
    #expect(entry.audioUrl == "https://api.dictionaryapi.dev/media/pronunciations/en/resilient-us.mp3")

    #expect(entry.meanings.map(\.partOfSpeech) == ["adjective"])
    let adjective = entry.meanings[0]
    #expect(adjective.definitions.count == 2)
    #expect(adjective.definitions[0].definition
        == "(of objects or substances) Returning quickly to original shape after force is applied; elastic.")
    #expect(adjective.definitions[0].example == nil)
    // 뜻 단위 동의어는 빈 배열로 온다 — nil 로 바꿔 화면이 빈 줄을 그리지 않게 한다.
    #expect(adjective.definitions[0].synonyms == nil)
    // 품사 단위 동의어. 계약에 Meaning.synonyms 를 추가하지 않았다면 버려졌을 값이다.
    #expect(adjective.synonyms == ["bendable", "flexible", "strong"])
}

@Test func mapsRunningWithManyPartsOfSpeechAndAudioOnlyInTheSecondPhonetic() throws {
    let entry = try DictionaryAPIMapper.map(fixture("dictionaryapi-running"), fetchedAt: 0)

    // IPA 는 전달 과정에서 뭉개지지 않도록 코드 포인트로 적는다: /ˈɹʌnɪŋ/
    #expect(entry.phonetic == "/\u{2C8}\u{279}\u{28C}n\u{26A}\u{14B}/")
    // 첫 phonetics 항목의 audio 는 빈 문자열이다. 건너뛰고 두 번째를 골라야 한다.
    #expect(entry.audioUrl == "https://api.dictionaryapi.dev/media/pronunciations/en/running-us.mp3")
    #expect(entry.meanings.map(\.partOfSpeech) == ["verb", "noun", "adjective", "adverb", "preposition"])
    #expect(entry.meanings[0].definitions.count == 34)
    #expect(entry.meanings[0].definitions[0].definition == "To move swiftly.")
    #expect(entry.meanings[2].synonyms == ["runny"])
    #expect(entry.meanings[0].synonyms == nil)
}

/// 합성 데이터 — 실제 픽스처는 두 개 모두 항목이 하나뿐이라 동형이의어 병합을 검증할 수 없다.
@Test func mergesSamePartOfSpeechAcrossEntriesInFirstSeenOrder() throws {
    let json = """
    [
      {"word":"bank","phonetics":[],"meanings":[
        {"partOfSpeech":"noun","definitions":[{"definition":"edge of a river"}],"synonyms":["shore"]}
      ]},
      {"word":"bank","phonetics":[],"meanings":[
        {"partOfSpeech":"noun","definitions":[{"definition":"a financial institution"}],"synonyms":["shore","lender"]},
        {"partOfSpeech":"verb","definitions":[{"definition":"to deposit money","example":"I bank online."}]}
      ]}
    ]
    """
    let entry = try DictionaryAPIMapper.map(Data(json.utf8), fetchedAt: 0)

    #expect(entry.meanings.map(\.partOfSpeech) == ["noun", "verb"])
    #expect(entry.meanings[0].definitions.map(\.definition) == ["edge of a river", "a financial institution"])
    #expect(entry.meanings[0].synonyms == ["shore", "lender"])
    #expect(entry.meanings[1].definitions[0].example == "I bank online.")
}

@Test func marksMultiWordTermsAsPhrases() throws {
    let json = #"[{"word":"take off","phonetics":[],"meanings":[]}]"#
    #expect(try DictionaryAPIMapper.map(Data(json.utf8), fetchedAt: 0).type == .phrase)
}

@Test func rejectsAnEmptyResponseArray() {
    #expect(throws: DictionaryAPIMapper.MappingError.noEntries) {
        try DictionaryAPIMapper.map(Data("[]".utf8), fetchedAt: 0)
    }
}
