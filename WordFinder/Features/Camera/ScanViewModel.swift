import Foundation
import Observation

enum ScanState: Equatable {
    /// 대기. `message` 가 있으면 직전 시도가 왜 실패했는지 알려준다.
    case idle(message: String?)
    /// 인식 중. `preview` 는 지금 읽히고 있는 문자열.
    case scanning(preview: String?)
    /// 확정. 시트가 올라간다.
    case settled([ScannedWord])
}

@MainActor
@Observable
final class ScanViewModel {
    static let timeoutMessage = "Couldn't read that — try moving closer"
    static let permissionMessage = "Camera access is off. Turn it on in Settings to scan."
    static let unsupportedMessage = "This device can't scan text."

    private(set) var state: ScanState = .idle(message: nil)

    private let recognizer: TextRecognizer
    private let detector: StabilityDetector
    private let now: () -> TimeInterval

    /// 마지막으로 인식기가 준 값. `tick()` 이 타임아웃을 굴릴 때 다시 먹인다.
    private var lastText: String?

    init(
        recognizer: TextRecognizer,
        detector: StabilityDetector = StabilityDetector(),
        now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }
    ) {
        self.recognizer = recognizer
        self.detector = detector
        self.now = now
        self.recognizer.onText = { [weak self] text in
            self?.handle(text)
        }
    }

    func tapScan() {
        guard case .idle = state else { return }
        detector.start(at: now())
        lastText = nil
        do {
            try recognizer.startScanning()
            state = .scanning(preview: nil)
        } catch RecognizerError.permissionDenied {
            recognizer.stopScanning()
            detector.reset()
            state = .idle(message: Self.permissionMessage)
        } catch {
            recognizer.stopScanning()
            detector.reset()
            state = .idle(message: Self.unsupportedMessage)
        }
    }

    func tapCancel() {
        guard case .scanning = state else { return }
        stop()
        state = .idle(message: nil)
    }

    func dismissSheet() {
        guard case .settled = state else { return }
        state = .idle(message: nil)
    }

    /// 인식기가 콜백을 주지 않아도 타임아웃이 동작하도록 화면이 주기적으로 호출한다.
    /// `DataScannerViewController` 의 델리게이트는 프레임 단위가 아니라 이벤트
    /// 단위여서, 박스 안에 아무것도 없으면 콜백이 아예 오지 않는다.
    func tick() {
        handle(lastText)
    }

    private func handle(_ text: String?) {
        guard case .scanning = state else { return }
        lastText = text

        switch detector.ingest(text, at: now()) {
        case .waiting:
            state = .scanning(preview: text)
        case .settled(let confirmed):
            let words = WordTokenizer.tokenize(confirmed)
            // 구두점만 있는 경우처럼 토큰이 하나도 안 남으면 확정으로 치지 않는다.
            guard !words.isEmpty else {
                state = .scanning(preview: text)
                return
            }
            stop()
            state = .settled(words)
        case .timedOut:
            stop()
            state = .idle(message: Self.timeoutMessage)
        }
    }

    private func stop() {
        recognizer.stopScanning()
        detector.reset()
    }
}
