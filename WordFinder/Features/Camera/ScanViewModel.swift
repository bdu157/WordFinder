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
    static let startFailureMessage = "Couldn't start the camera. Try again."

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
        } catch RecognizerError.unsupportedDevice {
            recognizer.stopScanning()
            detector.reset()
            state = .idle(message: Self.unsupportedMessage)
        } catch {
            recognizer.stopScanning()
            detector.reset()
            state = .idle(message: Self.startFailureMessage)
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

        // 구두점만 있는 등 쓸 수 있는 단어가 하나도 안 나오는 입력은 "아무것도 못 읽음"과
        // 똑같이 취급한다. 그래야 확정 후보가 되지 않고 타임아웃도 계속 흐른다.
        // 프리뷰에는 정규화 전 원문을 그대로 보여준다.
        let usable = text.flatMap { WordTokenizer.tokenize($0).isEmpty ? nil : $0 }

        switch detector.ingest(usable, at: now()) {
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
