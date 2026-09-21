import Foundation
import Testing
@testable import WordFinder

/// 네트워크 없이 조회 결과를 정해 두는 가짜 사전. 모델이 어떤 단어로 조회했는지 기록한다 —
/// 서버 구현체로 갈아끼울 때 거치는 지점이라, 엉뚱한 단어를 넘기는 버그를 잡아야 한다.
private final class FakeDictionaryService: DictionaryService, @unchecked Sendable {
    let result: Result<DictEntry, any Error>
    private(set) var requestedTerms: [String] = []

    init(result: Result<DictEntry, any Error>) {
        self.result = result
    }

    func lookUp(_ term: String) async throws -> DictEntry {
        requestedTerms.append(term)
        return try result.get()
    }
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
    let service = FakeDictionaryService(result: .success(sampleEntry))
    let model = WordLookupModel(term: "resilient", service: service)
    #expect(model.term == "resilient")
    #expect(model.state == .loading)
    #expect(model.fallbackNotice == nil)
    #expect(service.requestedTerms.isEmpty)
}

@Test @MainActor func showsTheEntryWhenTheLookupSucceeds() async {
    let service = FakeDictionaryService(result: .success(sampleEntry))
    let model = WordLookupModel(term: "resilient", service: service)
    await model.load()
    #expect(model.state == .loaded(sampleEntry))
    #expect(model.fallbackNotice == nil)
    #expect(service.requestedTerms == ["resilient"])
}

@Test @MainActor func fallsBackWithTheNotFoundNotice() async {
    let service = FakeDictionaryService(result: .failure(DictionaryError.notFound))
    let model = WordLookupModel(term: "qwxzvbnk", service: service)
    await model.load()
    #expect(model.state == .fallback(.notFound))
    #expect(model.fallbackNotice == WordLookupModel.notFoundNotice)
    #expect(service.requestedTerms == ["qwxzvbnk"])
}

@Test @MainActor func fallsBackWithTheUnavailableNotice() async {
    let service = FakeDictionaryService(result: .failure(DictionaryError.unavailable))
    let model = WordLookupModel(term: "urban", service: service)
    await model.load()
    #expect(model.state == .fallback(.unavailable))
    #expect(model.fallbackNotice == WordLookupModel.unavailableNotice)
    #expect(service.requestedTerms == ["urban"])
}

/// 서버 구현체가 `DictionaryError` 가 아닌 에러를 던져도 화면이 멈추지 않고 폴백해야 한다.
@Test @MainActor func treatsAnyOtherErrorAsUnavailable() async {
    let service = FakeDictionaryService(result: .failure(SomeOtherError()))
    let model = WordLookupModel(term: "urban", service: service)
    await model.load()
    #expect(model.state == .fallback(.unavailable))
    #expect(service.requestedTerms == ["urban"])
}
