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
        do {
            try recognizer.startScanning()
            state = .scanning(preview: nil)
        } catch RecognizerError.permissionDenied {
            detector.reset()
            state = .idle(message: Self.permissionMessage)
        } catch {
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

    private func handle(_ text: String?) {
        guard case .scanning = state else { return }

        switch detector.ingest(text, at: now()) {
        case .waiting:
            state = .scanning(preview: text)
        case .settled(let confirmed):
            stop()
            state = .settled(WordTokenizer.tokenize(confirmed))
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
