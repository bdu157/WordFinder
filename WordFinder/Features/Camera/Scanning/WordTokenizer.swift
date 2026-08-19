import Foundation

/// 확정된 OCR 문자열을 화면에 띄울 단어 단위로 쪼갠다.
///
/// **임시 구현이다.** PLAN.md F4는 단어 토큰화와 표제어 추정을 서버(Cloud
/// Functions) 몫으로 정해뒀다. 서버가 붙으면 이 파일과 테스트를 통째로 삭제한다.
/// 그래서 여기에는 표제어 추정(`running` → `run`) 같은 로직을 넣지 않는다 —
/// 공백으로 자르고 바깥쪽 구두점만 떼는 것이 전부다.
/// 삭제할 때 `ScanViewModel.handle` 의 `usable` 필터도 함께 정리해야 한다 — 그쪽도
/// "쓸 단어가 하나도 안 나오는 입력" 판정에 이 타입을 쓰고 있다.
enum WordTokenizer {
    /// 이보다 짧은 토큰은 노이즈로 보고 버린다.
    ///
    /// `ScanViewModel` 이 인식 문자열을 detector 에 넣기 전에 이 토크나이저로 거르므로,
    /// **실제 앱에서 최소 길이를 결정하는 것은 이 상수 하나뿐이다.**
    /// `StabilityDetector.minimumLength` 는 그 경로에서는 도달하지 않는다.
    static let minimumLength = 2

    static func tokenize(_ text: String) -> [ScannedWord] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map { trimOuterPunctuation(String($0)) }
            .filter { $0.count >= minimumLength }
            .map(ScannedWord.init(term:))
    }

    /// 단어 바깥쪽의 구두점만 제거한다. 안쪽 하이픈·아포스트로피는 단어의
    /// 일부이므로 남긴다 (`well-being`, `doesn't`).
    private static func trimOuterPunctuation(_ token: String) -> String {
        let allowedInside = CharacterSet(charactersIn: "-'’")

        let strippable = CharacterSet.punctuationCharacters
            .union(.symbols)
            .subtracting(allowedInside)

        var slice = Substring(token)
        while let first = slice.first, first.unicodeScalars.allSatisfy(strippable.contains) {
            slice = slice.dropFirst()
        }
        while let last = slice.last, last.unicodeScalars.allSatisfy(strippable.contains) {
            slice = slice.dropLast()
        }
        // 바깥쪽 하이픈·아포스트로피는 단어의 일부가 아니므로 여기서 마저 떼어낸다.
        return String(slice).trimmingCharacters(in: allowedInside)
    }
}
