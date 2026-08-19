import Testing
@testable import WordFinder

/// 모든 테스트는 가짜 시각(초 단위 Double)을 직접 넘긴다. 실제로 기다리지 않는다.
@Test func settlesAfterStabilityWindow() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)

    #expect(detector.ingest("resilient", at: 0.0) == .waiting)
    #expect(detector.ingest("resilient", at: 0.3) == .waiting)
    #expect(detector.ingest("resilient", at: 0.6) == .settled("resilient"))
}

@Test func changingTextResetsTheTimer() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)

    #expect(detector.ingest("resilient", at: 0.0) == .waiting)
    #expect(detector.ingest("resilent", at: 0.5) == .waiting)   // 다르게 읽힘 → 리셋
    #expect(detector.ingest("resilent", at: 0.9) == .waiting)   // 리셋 후 0.4초뿐
    #expect(detector.ingest("resilent", at: 1.1) == .settled("resilent"))
}

@Test func normalizesCaseAndWhitespaceBeforeComparing() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)

    #expect(detector.ingest("  Resilient ", at: 0.0) == .waiting)
    #expect(detector.ingest("resilient", at: 0.3) == .waiting)      // 정규화하면 같음 → 리셋 안 됨
    #expect(detector.ingest("RESILIENT", at: 0.6) == .settled("resilient"))
}

@Test func collapsesInnerWhitespaceWhenNormalizing() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)

    #expect(detector.ingest("urban  systems", at: 0.0) == .waiting)
    #expect(detector.ingest("urban systems", at: 0.6) == .settled("urban systems"))
}

@Test func ignoresTextShorterThanMinimumLength() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10, minimumLength: 2)
    detector.start(at: 0)

    #expect(detector.ingest("a", at: 0.0) == .waiting)
    #expect(detector.ingest("a", at: 5.0) == .waiting)   // 아무리 오래 유지돼도 확정 안 됨
}

@Test func emptyInputResetsTheTimer() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)

    #expect(detector.ingest("resilient", at: 0.0) == .waiting)
    #expect(detector.ingest(nil, at: 0.3) == .waiting)          // 박스가 비었음
    #expect(detector.ingest("resilient", at: 0.5) == .waiting)  // 처음부터 다시
    #expect(detector.ingest("resilient", at: 1.1) == .settled("resilient"))
}

@Test func timesOutWhenNothingEverSettles() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)

    #expect(detector.ingest(nil, at: 5.0) == .waiting)
    #expect(detector.ingest(nil, at: 10.0) == .timedOut)
}

@Test func timeoutIsMeasuredFromStartNotFromLastChange() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 100)

    #expect(detector.ingest("ab", at: 105.0) == .waiting)
    #expect(detector.ingest("cd", at: 109.9) == .waiting)
    #expect(detector.ingest("ef", at: 110.0) == .timedOut)
}

@Test func settlingWinsOverTimeoutAtTheSameInstant() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)

    #expect(detector.ingest("resilient", at: 9.4) == .waiting)
    #expect(detector.ingest("resilient", at: 10.0) == .settled("resilient"))
}

@Test func resetClearsPreviousProgress() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)
    #expect(detector.ingest("resilient", at: 0.0) == .waiting)

    detector.reset()
    detector.start(at: 100)
    #expect(detector.ingest("resilient", at: 100.5) == .waiting)   // 이전 진행 무효
    #expect(detector.ingest("resilient", at: 101.1) == .settled("resilient"))
}
