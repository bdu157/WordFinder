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

/// 합성 데이터 — 설계 문서 §13 이 2단계 숙제로 남긴 것이다. 실제 픽스처는 둘 다 항목이
/// 하나뿐이라, 발음기호와 음성을 **여러 항목에 걸쳐** 고르는 경로가 검증된 적이 없었다.
///
/// 항목 1은 둘 다 빈 문자열, 항목 2에만 `phonetics[].text`, 항목 3에만 음성이 있고 항목 3의
/// 항목 단위 `phonetic` 은 골라지면 안 되는 값이다. 이렇게 두면 세 가지가 한꺼번에 고정된다 —
/// 빈 문자열을 건너뛰는지, 항목 순서가 항목 단위 `phonetic` 보다 앞서는지, 그리고 발음기호와
/// 음성을 **서로 다른 항목에서** 독립적으로 고르는지.
@Test func picksPhoneticAndAudioIndependentlyAcrossEntries() throws {
    // IPA 는 코드 포인트로 적는다: /bæŋk/
    let ipa = "/b\u{E6}\u{14B}k/"
    let json = """
    [
      {"word":"bank","phonetic":"","phonetics":[{"text":"","audio":""}],"meanings":[]},
      {"word":"bank","phonetics":[{"text":"\(ipa)","audio":""}],"meanings":[]},
      {"word":"bank","phonetic":"/not-this-one/",
       "phonetics":[{"audio":"https://example.com/bank-us.mp3"}],"meanings":[]}
    ]
    """
    let entry = try DictionaryAPIMapper.map(Data(json.utf8), fetchedAt: 0)

    // 항목 3의 항목 단위 `phonetic` 을 먼저 보는 구현이라면 "/not-this-one/" 이 나온다.
    #expect(entry.phonetic == ipa)
    // 발음기호를 항목 2에서 골랐지만 음성은 항목 3에서 와야 한다.
    #expect(entry.audioUrl == "https://example.com/bank-us.mp3")
}

/// 합성 데이터 — **한 항목 안에서의** 우선순위를 고정한다. 위 테스트가 항목 *사이* 순서를
/// 덮는 것과 짝이다.
///
/// 이 경로는 실제 픽스처로는 검증할 수 없다. `running` 은 `phonetic` 과 `phonetics[].text` 가
/// 같은 값이고 `resilient` 는 둘 다 없어서, 순서를 뒤집어도 두 픽스처 모두 통과한다.
/// 스펙 §6 과 `DictionaryAPIMapper.phonetic(in:)` 주석이 "`phonetic` → `phonetics[].text` 순"
/// 이라고 선언하므로, 그 선언을 여기서 고정한다. 음성도 마찬가지로 **첫** 값이어야 한다.
@Test func prefersEntryLevelPhoneticAndTheFirstAudioWithinOneEntry() throws {
    let json = """
    [{"word":"bank",
      "phonetic":"/entry-level/",
      "phonetics":[
        {"text":"/from-phonetics/","audio":"https://example.com/first.mp3"},
        {"text":"/later/","audio":"https://example.com/second.mp3"}
      ],
      "meanings":[]}]
    """
    let entry = try DictionaryAPIMapper.map(Data(json.utf8), fetchedAt: 0)

    // 항목 단위 `phonetic` 이 같은 항목의 `phonetics[].text` 보다 앞선다.
    #expect(entry.phonetic == "/entry-level/")
    // 음성은 마지막이 아니라 첫 값이다.
    #expect(entry.audioUrl == "https://example.com/first.mp3")
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

/// 합성 데이터 — 실제 픽스처의 뜻 단위 동의어는 전부 비어 있어서, 이 경로가 값을 실제로
/// 옮기는지 검증할 수 없었다. 중복과 빈 문자열이 제거되는지도 함께 고정한다.
@Test func keepsDefinitionLevelSynonymsDeduplicated() throws {
    let json = """
    [{"word":"quick","phonetics":[],"meanings":[
      {"partOfSpeech":"adjective","definitions":[
        {"definition":"moving fast","synonyms":["fast","rapid","fast",""]}
      ]}
    ]}]
    """
    let entry = try DictionaryAPIMapper.map(Data(json.utf8), fetchedAt: 0)
    #expect(entry.meanings[0].definitions[0].synonyms == ["fast", "rapid"])
    #expect(entry.meanings[0].synonyms == nil)
}
