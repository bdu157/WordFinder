import Foundation
import Testing
@testable import WordFinder

private func fixture(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

@Test func interprets200AsAMappedEntry() throws {
    let entry = try DictionaryAPIClient.interpret(status: 200, data: fixture("dictionaryapi-resilient"), fetchedAt: 42)
    #expect(entry.term == "resilient")
    #expect(entry.fetchedAt == 42)
}

/// 404 본문은 녹화하지 못했다 — 2026-09-21 에는 없는 단어가 전부 522 로 왔다.
/// 상태 코드만으로 판단하므로 본문은 비워 둔다.
@Test func interprets404AsNotFound() {
    #expect(throws: DictionaryError.notFound) {
        try DictionaryAPIClient.interpret(status: 404, data: Data(), fetchedAt: 0)
    }
}

@Test(arguments: [522, 500, 503, 429])
func interpretsServerErrorsAsUnavailable(status: Int) {
    #expect(throws: DictionaryError.unavailable) {
        try DictionaryAPIClient.interpret(status: status, data: Data(), fetchedAt: 0)
    }
}

@Test func interpretsAnUnreadable200AsUnavailable() {
    #expect(throws: DictionaryError.unavailable) {
        try DictionaryAPIClient.interpret(status: 200, data: Data("<html>".utf8), fetchedAt: 0)
    }
}

@Test func interpretsAnEmpty200AsUnavailable() {
    #expect(throws: DictionaryError.unavailable) {
        try DictionaryAPIClient.interpret(status: 200, data: Data("[]".utf8), fetchedAt: 0)
    }
}

/// 3초 제한은 요청 전체 시간이어야 한다. timeoutIntervalForRequest 는 "데이터가 안 오는 공백"
/// 기준이라 조금씩 흘려보내는 서버에서는 3초를 넘길 수 있고, 실제로 상한을 거는 것은
/// timeoutIntervalForResource 다. 둘 중 하나라도 지우면 이 테스트가 실패해야 한다.
@Test func sessionCapsTheWholeRequestAtTheBudget() {
    let configuration = DictionaryAPIClient.makeSession().configuration
    #expect(DictionaryAPIClient.timeout == 3)
    #expect(configuration.timeoutIntervalForRequest == DictionaryAPIClient.timeout)
    #expect(configuration.timeoutIntervalForResource == DictionaryAPIClient.timeout)
}
