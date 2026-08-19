import Foundation

enum StabilityOutcome: Equatable {
    /// 아직 확정도 포기도 아님. 계속 인식한다.
    case waiting
    /// 확정. 실어 나르는 문자열은 정규화된 값이다.
    case settled(String)
    /// 제한 시간 안에 아무것도 확정되지 않았다.
    case timedOut
}

/// OCR은 매 프레임 조금씩 다르게 읽는다 (`resilient` → `Resilient` → `resilient `).
/// 그래서 정규화한 값이 충분히 오래 유지될 때에만 확정으로 본다.
///
/// `DataScannerViewController`는 텍스트 신뢰도 점수를 주지 않는다. "얼마나 확실한가"
/// 대신 **"얼마나 오래 같은가"** 로 판정하는 이유다.
///
/// 시각을 인자로 받는다. 시계를 직접 읽으면 테스트가 실제로 0.6초를 기다려야 한다.
final class StabilityDetector {
    private let stabilityWindow: TimeInterval
    private let timeout: TimeInterval
    /// 확정 후보로 인정할 최소 길이.
    ///
    /// `ScanViewModel` 경로에서는 도달하지 않는다 — 거기서는 `WordTokenizer` 가 먼저
    /// 걸러낸 문자열만 들어오기 때문이다. 이 상수는 이 타입의 유닛 테스트와, 토크나이저를
    /// 거치지 않는 미래의 직접 호출자를 위해 남아 있다. 실기기 튜닝은
    /// `WordTokenizer.minimumLength` 를 조정해야 한다.
    private let minimumLength: Int

    private var startedAt: TimeInterval?
    private var candidate: String?
    private var candidateSince: TimeInterval?

    init(stabilityWindow: TimeInterval = 0.6, timeout: TimeInterval = 10, minimumLength: Int = 2) {
        self.stabilityWindow = stabilityWindow
        self.timeout = timeout
        self.minimumLength = minimumLength
    }

    func start(at now: TimeInterval) {
        startedAt = now
        candidate = nil
        candidateSince = nil
    }

    func reset() {
        startedAt = nil
        candidate = nil
        candidateSince = nil
    }

    /// - Parameter raw: 이번 프레임에서 읽힌 문자열. 박스가 비었으면 `nil`.
    func ingest(_ raw: String?, at now: TimeInterval) -> StabilityOutcome {
        guard let startedAt else { return .waiting }

        let normalized = raw.map(Self.normalize)

        if let normalized, normalized.count >= minimumLength {
            if normalized == candidate {
                if let since = candidateSince, now - since >= stabilityWindow {
                    return .settled(normalized)
                }
            } else {
                candidate = normalized
                candidateSince = now
            }
        } else {
            // 아무것도 안 보이거나 너무 짧다 — 처음부터 다시.
            candidate = nil
            candidateSince = nil
        }

        // 확정이 우선이므로 타임아웃 판정은 마지막에 한다.
        if now - startedAt >= timeout { return .timedOut }
        return .waiting
    }

    /// 앞뒤 공백 제거, 소문자, 연속 공백을 하나로.
    static func normalize(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }
}
