import Foundation
import Testing
@testable import WordFinder

/// 카메라 없이 상태 전이만 검증하기 위한 가짜 인식기.
@MainActor
final class FakeRecognizer: TextRecognizer {
    var onText: ((String?) -> Void)?
    var isScanning = false
    var startError: Error?
    static var isSupported: Bool { true }

    func startScanning() throws {
        isScanning = true
        if let startError { throw startError }
    }
    func stopScanning() { isScanning = false }

    /// 테스트에서 인식 프레임 한 장을 흘려보낸다.
    func emit(_ text: String?) { onText?(text) }
}

/// 테스트가 시간을 직접 굴린다.
final class FakeClock {
    var now: TimeInterval = 0
    func read() -> TimeInterval { now }
}

@MainActor
private func makeSUT() -> (ScanViewModel, FakeRecognizer, FakeClock) {
    let recognizer = FakeRecognizer()
    let clock = FakeClock()
    let vm = ScanViewModel(
        recognizer: recognizer,
        detector: StabilityDetector(stabilityWindow: 0.6, timeout: 10),
        now: clock.read
    )
    return (vm, recognizer, clock)
}

@Test @MainActor func startsIdleWithoutMessageAndDoesNotScan() {
    let (vm, recognizer, _) = makeSUT()
    #expect(vm.state == .idle(message: nil))
    #expect(recognizer.isScanning == false)
}

@Test @MainActor func tappingScanStartsRecognizing() {
    let (vm, recognizer, _) = makeSUT()
    vm.tapScan()
    #expect(vm.state == .scanning(preview: nil))
    #expect(recognizer.isScanning == true)
}

@Test @MainActor func recognizedTextShowsAsPreviewBeforeSettling() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()

    clock.now = 0.1
    recognizer.emit("resilient")
    #expect(vm.state == .scanning(preview: "resilient"))
}

@Test @MainActor func stableTextSettlesIntoWords() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()

    clock.now = 0.0
    recognizer.emit("resilient urban")
    clock.now = 0.6
    recognizer.emit("resilient urban")

    #expect(vm.state == .settled([ScannedWord(term: "resilient"), ScannedWord(term: "urban")]))
}

@Test @MainActor func settlingStopsTheRecognizer() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()

    clock.now = 0.0
    recognizer.emit("resilient")
    clock.now = 0.6
    recognizer.emit("resilient")

    #expect(recognizer.isScanning == false)
}

@Test @MainActor func framesArrivingAfterSettlingAreIgnored() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()

    clock.now = 0.0
    recognizer.emit("resilient")
    clock.now = 0.6
    recognizer.emit("resilient")
    let settled = vm.state

    clock.now = 2.0
    recognizer.emit("something else")
    #expect(vm.state == settled)
}

@Test @MainActor func dismissingSheetReturnsToIdleWithoutMessage() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()
    clock.now = 0.0
    recognizer.emit("resilient")
    clock.now = 0.6
    recognizer.emit("resilient")

    vm.dismissSheet()
    #expect(vm.state == .idle(message: nil))
}

@Test @MainActor func cancelReturnsToIdleAndStopsRecognizer() {
    let (vm, recognizer, _) = makeSUT()
    vm.tapScan()
    vm.tapCancel()

    #expect(vm.state == .idle(message: nil))
    #expect(recognizer.isScanning == false)
}

@Test @MainActor func timeoutReturnsToIdleWithGuidanceMessage() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()

    clock.now = 10.0
    recognizer.emit(nil)

    #expect(vm.state == .idle(message: ScanViewModel.timeoutMessage))
    #expect(recognizer.isScanning == false)
}

@Test @MainActor func scanningAgainAfterTimeoutClearsTheMessage() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()
    clock.now = 10.0
    recognizer.emit(nil)

    clock.now = 11.0
    vm.tapScan()
    #expect(vm.state == .scanning(preview: nil))
}

@Test @MainActor func permissionDeniedShowsSettingsMessage() {
    let (vm, recognizer, _) = makeSUT()
    recognizer.startError = RecognizerError.permissionDenied

    vm.tapScan()
    #expect(vm.state == .idle(message: ScanViewModel.permissionMessage))
    #expect(recognizer.isScanning == false)
}

@Test @MainActor func unsupportedDeviceShowsItsOwnMessage() {
    let (vm, recognizer, _) = makeSUT()
    recognizer.startError = RecognizerError.unsupportedDevice

    vm.tapScan()
    #expect(vm.state == .idle(message: ScanViewModel.unsupportedMessage))
    #expect(recognizer.isScanning == false)
}

private struct SomeOtherError: Error {}

@Test @MainActor func unexpectedStartErrorShowsRetryMessage() {
    let (vm, recognizer, _) = makeSUT()
    recognizer.startError = SomeOtherError()

    vm.tapScan()
    #expect(vm.state == .idle(message: ScanViewModel.startFailureMessage))
    #expect(recognizer.isScanning == false)
}

@Test @MainActor func tapScanIsIgnoredWhileScanning() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()
    clock.now = 0.3
    recognizer.emit("resilient")
    vm.tapScan()                     // 무시되어야 한다 — 무시되지 않으면 창이 리셋된다
    clock.now = 0.9
    recognizer.emit("resilient")
    #expect(vm.state == .settled([ScannedWord(term: "resilient")]))
}

@Test @MainActor func tapCancelIsIgnoredWhenIdle() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()
    clock.now = 10.0
    recognizer.emit(nil)
    #expect(vm.state == .idle(message: ScanViewModel.timeoutMessage))

    // 가드가 없으면 이 호출이 안내 문구를 지워버린다.
    vm.tapCancel()
    #expect(vm.state == .idle(message: ScanViewModel.timeoutMessage))
    #expect(recognizer.isScanning == false)
}

@Test @MainActor func dismissSheetIsIgnoredWhileScanning() {
    let (vm, _, _) = makeSUT()
    vm.tapScan()
    vm.dismissSheet()                // 무시되어야 한다
    #expect(vm.state == .scanning(preview: nil))
}

@Test @MainActor func tickDrivesTimeoutWhenRecognizerNeverCallsBack() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()
    // 인식기가 콜백을 단 한 번도 주지 않는다 — 빈 벽을 비춘 경우
    clock.now = 10.0
    vm.tick()
    #expect(vm.state == .idle(message: ScanViewModel.timeoutMessage))
    #expect(recognizer.isScanning == false)
}

@Test @MainActor func tickIsIgnoredWhenNotScanning() {
    let (vm, _, clock) = makeSUT()
    clock.now = 100.0
    vm.tick()
    #expect(vm.state == .idle(message: nil))
}

@Test @MainActor func punctuationOnlyTextDoesNotSettle() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()
    clock.now = 0.0
    recognizer.emit("?!")
    clock.now = 0.6
    recognizer.emit("?!")
    #expect(vm.state == .scanning(preview: "?!"))
    #expect(recognizer.isScanning == true)
}

@Test @MainActor func punctuationOnlyTextEventuallyTimesOut() {
    let (vm, recognizer, clock) = makeSUT()
    vm.tapScan()
    clock.now = 0.0
    recognizer.emit("?!")
    clock.now = 5.0
    recognizer.emit("?!")
    #expect(vm.state == .scanning(preview: "?!"))
    clock.now = 10.0
    recognizer.emit("?!")
    #expect(vm.state == .idle(message: ScanViewModel.timeoutMessage))
    #expect(recognizer.isScanning == false)
}
