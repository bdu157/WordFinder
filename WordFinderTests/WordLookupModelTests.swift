import Foundation
import Testing
@testable import WordFinder

/// 네트워크 없이 조회 결과를 정해 두는 가짜 사전.
private struct FakeDictionaryService: DictionaryService {
    let result: Result<DictEntry, any Error>
    func lookUp(_ term: String) async throws -> DictEntry { try result.get() }
}

private struct SomeOtherError: Error {}

private let sampleEntry = DictEntry(
    term: "resilient", lang: "en", type: .word, phonetic: nil, audioUrl: nil,
    meanings: [DictEntry.Meaning(
        partOfSpeech: "adjective",
        definitions: [DictEntry.Definition(definition: "elastic", example: nil, synonyms: nil)],
        synonyms: nil
    )],
    source: .dictionaryapi, fetchedAt: 0
)

@Test @MainActor func startsLoadingWithTheTappedTerm() {
    let model = WordLookupModel(term: "resilient", service: FakeDictionaryService(result: .success(sampleEntry)))
    #expect(model.term == "resilient")
    #expect(model.state == .loading)
    #expect(model.fallbackNotice == nil)
}

@Test @MainActor func showsTheEntryWhenTheLookupSucceeds() async {
    let model = WordLookupModel(term: "resilient", service: FakeDictionaryService(result: .success(sampleEntry)))
    await model.load()
    #expect(model.state == .loaded(sampleEntry))
    #expect(model.fallbackNotice == nil)
}

@Test @MainActor func fallsBackWithTheNotFoundNotice() async {
    let model = WordLookupModel(term: "qwxzvbnk", service: FakeDictionaryService(result: .failure(DictionaryError.notFound)))
    await model.load()
    #expect(model.state == .fallback(.notFound))
    #expect(model.fallbackNotice == WordLookupModel.notFoundNotice)
}

@Test @MainActor func fallsBackWithTheUnavailableNotice() async {
    let model = WordLookupModel(term: "urban", service: FakeDictionaryService(result: .failure(DictionaryError.unavailable)))
    await model.load()
    #expect(model.state == .fallback(.unavailable))
    #expect(model.fallbackNotice == WordLookupModel.unavailableNotice)
}

/// 서버 구현체가 `DictionaryError` 가 아닌 에러를 던져도 화면이 멈추지 않고 폴백해야 한다.
@Test @MainActor func treatsAnyOtherErrorAsUnavailable() async {
    let model = WordLookupModel(term: "urban", service: FakeDictionaryService(result: .failure(SomeOtherError())))
    await model.load()
    #expect(model.state == .fallback(.unavailable))
}
