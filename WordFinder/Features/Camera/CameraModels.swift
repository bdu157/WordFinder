import Foundation

/// 스캔이 확정한 단어 하나. `WordTokenizer` 가 만들고 단어 목록 시트가 보여준다.
struct ScannedWord: Identifiable, Equatable {
    let id = UUID()
    let term: String

    /// `id` 는 인스턴스마다 다르므로 단어 자체로 비교한다.
    static func == (lhs: ScannedWord, rhs: ScannedWord) -> Bool {
        lhs.term == rhs.term
    }
}

/// 프리뷰 전용 샘플. 실제 화면은 OCR 결과와 사전 응답을 쓴다.
enum CameraMock {
    static let recognizedWords = [
        ScannedWord(term: "resilient"),
        ScannedWord(term: "urban"),
        ScannedWord(term: "absorb"),
        ScannedWord(term: "shocks"),
    ]
}
