# 카메라 OCR 1단계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 카메라로 단어를 비추고 Scan을 누르면 실제 OCR로 인식한 단어 목록이 바텀시트에 뜬다.

**Architecture:** VisionKit `DataScannerViewController`를 `TextRecognizer` 프로토콜 뒤에 감춰 나중에 AVFoundation+Vision으로 교체할 수 있게 한다. 인식 문자열의 흔들림은 `StabilityDetector`가 "정규화 후 같은 값이 0.6초 유지"로 걸러내고, `WordTokenizer`가 단어로 쪼갠다. 이 둘은 카메라·UIKit 의존이 전혀 없는 순수 로직이라 시뮬레이터에서 유닛 테스트로 전부 검증한다.

**Tech Stack:** Swift 5.10, SwiftUI, VisionKit, Swift Testing (Xcode 내장), XcodeGen

**Spec:** `docs/superpowers/specs/2026-08-19-camera-ocr-design.md`

## Global Constraints

- iOS 17.0 최소, Swift 5.10, iPhone 세로 전용 (`project.yml`이 강제)
- **`WordFinder.xcodeproj`는 절대 손으로 고치지 않는다.** 구조 변경은 `project.yml`을 고치고 `xcodegen generate`
- **`.xcodeproj`는 커밋하지 않는다** (gitignore 대상)
- UI 문구는 **전부 영어**. 앱 전체가 영어다 (`Words found`, `History`, `Settings`)
- 색은 `Color.wf*` 토큰, 폰트는 `Font.wf*`만 사용. 원시 hex·임의 `Font.system` 금지. Primary 역할은 `Color.accentColor` (`AccentColor` 에셋)
- 튜닝 상수 3개는 이름 있는 상수로 분리: 안정 판정 **0.6초**, 타임아웃 **10초**, 최소 길이 **2글자**
- 표제어 추정(`running` → `run`)은 **클라이언트에 넣지 않는다.** 서버(PLAN.md F4) 몫
- 빌드 검증 명령:
  ```bash
  xcodebuild -project WordFinder.xcodeproj -scheme WordFinder \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
  ```
- 테스트 실행 명령:
  ```bash
  xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```
  테스트 실행 중 콘솔에 `CoreData: error: ...` 가 여러 줄 뜨는데, 테스트 호스트 앱이 SwiftData를 부팅하며 내는 **정상 노이즈**다. `** TEST SUCCEEDED **` 만 보면 된다.

## File Structure

| 파일 | 책임 |
|---|---|
| `project.yml` | 테스트 타겟 `WordFinderTests` 추가 (Task 1) |
| `WordFinder/Features/Camera/Scanning/WordTokenizer.swift` | 확정 문자열 → `[ScannedWord]`. 순수. **서버 F4 붙으면 삭제** |
| `WordFinder/Features/Camera/Scanning/StabilityDetector.swift` | 흔들리는 인식 문자열 → 확정 신호. 순수. 시간 주입 |
| `WordFinder/Features/Camera/Scanning/TextRecognizer.swift` | 인식기 프로토콜 + 인식 이벤트 타입 |
| `WordFinder/Features/Camera/Scanning/DataScannerRecognizer.swift` | VisionKit 구현체 |
| `WordFinder/Features/Camera/Scanning/ScannerViewRepresentable.swift` | `DataScannerViewController` ↔ SwiftUI 브리지 |
| `WordFinder/Features/Camera/ScanViewModel.swift` | 상태 머신. 위 조각들을 연결 |
| `WordFinder/Features/Camera/CameraView.swift` | 그리기. 배경 교체 + 하단 버튼 추가 |
| `WordFinderTests/…` | 순수 로직 테스트 |

Task 2·3은 카메라 없이 완결되는 순수 로직이라 먼저 만든다. Task 5·6이 실기기를 요구한다.

---

### Task 1: 테스트 타겟 만들기

**Files:**
- Modify: `project.yml`
- Test: `WordFinderTests/SmokeTests.swift` (신규)

**Interfaces:**
- Consumes: 없음
- Produces: `WordFinderTests` 타겟. 이후 모든 태스크가 여기에 테스트를 추가한다. `@testable import WordFinder` 로 앱 타입 접근 가능

- [ ] **Step 1: `project.yml`에 테스트 타겟 추가**

`targets:` 아래 `WordFinder:` 타겟 정의가 끝난 지점, 즉 `schemes:` 바로 위에 다음 블록을 넣는다 (들여쓰기 2칸 — `WordFinder:` 와 같은 레벨):

```yaml
  WordFinderTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: WordFinderTests
    dependencies:
      - target: WordFinder
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
```

그리고 기존 `schemes:` 블록의 `build.targets` 와 `test` 를 다음으로 교체한다:

```yaml
schemes:
  WordFinder:
    build:
      targets:
        WordFinder: all
        WordFinderTests: [test]
    test:
      config: Debug
      targets:
        - WordFinderTests
    run:
      config: Debug
    archive:
      config: Release
```

- [ ] **Step 2: 스모크 테스트 파일 작성**

`WordFinderTests/SmokeTests.swift`:

```swift
import Testing
@testable import WordFinder

@Test func testTargetIsWired() {
    #expect(1 + 1 == 2)
}
```

- [ ] **Step 3: 프로젝트 재생성**

```bash
xcodegen generate
```

Expected: `Created project at .../WordFinder.xcodeproj`

- [ ] **Step 4: 테스트 실행**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `✔ Test testTargetIsWired() passed` 와 `** TEST SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add project.yml WordFinderTests/SmokeTests.swift
git commit -m "chore: add WordFinderTests target with Swift Testing"
```

---

### Task 2: WordTokenizer

확정된 문자열을 화면에 띄울 단어들로 쪼갠다. **임시 코드** — 서버 F4가 붙으면 이 파일과 테스트를 통째로 삭제한다.

**Files:**
- Create: `WordFinder/Features/Camera/Scanning/WordTokenizer.swift`
- Test: `WordFinderTests/WordTokenizerTests.swift`

**Interfaces:**
- Consumes: `ScannedWord` (기존 `WordFinder/Features/Camera/CameraModels.swift`, `init(term:)` 은 자동 생성 멤버와이즈, `id` 는 자동 `UUID()`)
- Produces: `enum WordTokenizer { static func tokenize(_ text: String) -> [ScannedWord] }`

- [ ] **Step 1: 실패하는 테스트 작성**

`WordFinderTests/WordTokenizerTests.swift`:

```swift
import Testing
@testable import WordFinder

@Test func splitsOnWhitespace() {
    let words = WordTokenizer.tokenize("resilient urban systems")
    #expect(words.map(\.term) == ["resilient", "urban", "systems"])
}

@Test func stripsSurroundingPunctuation() {
    let words = WordTokenizer.tokenize("\"resilient,\" (urban) systems.")
    #expect(words.map(\.term) == ["resilient", "urban", "systems"])
}

@Test func keepsInnerHyphenAndApostrophe() {
    let words = WordTokenizer.tokenize("well-being doesn't")
    #expect(words.map(\.term) == ["well-being", "doesn't"])
}

@Test func collapsesRepeatedWhitespaceAndNewlines() {
    let words = WordTokenizer.tokenize("  resilient \n\n  urban  ")
    #expect(words.map(\.term) == ["resilient", "urban"])
}

@Test func dropsTokensShorterThanTwoCharacters() {
    let words = WordTokenizer.tokenize("a resilient I system")
    #expect(words.map(\.term) == ["resilient", "system"])
}

@Test func returnsEmptyForBlankInput() {
    #expect(WordTokenizer.tokenize("   ").isEmpty)
    #expect(WordTokenizer.tokenize("").isEmpty)
}

@Test func dropsPurePunctuationTokens() {
    let words = WordTokenizer.tokenize("resilient --- urban")
    #expect(words.map(\.term) == ["resilient", "urban"])
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'WordTokenizer' in scope`

- [ ] **Step 3: 구현**

`WordFinder/Features/Camera/Scanning/WordTokenizer.swift`:

```swift
import Foundation

/// 확정된 OCR 문자열을 화면에 띄울 단어 단위로 쪼갠다.
///
/// **임시 구현이다.** PLAN.md F4는 단어 토큰화와 표제어 추정을 서버(Cloud
/// Functions) 몫으로 정해뒀다. 서버가 붙으면 이 파일과 테스트를 통째로 삭제한다.
/// 그래서 여기에는 표제어 추정(`running` → `run`) 같은 로직을 넣지 않는다 —
/// 공백으로 자르고 바깥쪽 구두점만 떼는 것이 전부다.
enum WordTokenizer {
    /// 이보다 짧은 토큰은 노이즈로 보고 버린다.
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
```

- [ ] **Step 4: 통과 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, WordTokenizer 테스트 7개 전부 통과

- [ ] **Step 5: 커밋**

```bash
git add WordFinder/Features/Camera/Scanning/WordTokenizer.swift WordFinderTests/WordTokenizerTests.swift
git commit -m "feat: add WordTokenizer for splitting recognized text into words"
```

---

### Task 3: StabilityDetector

OCR 문자열의 흔들림을 걸러 "확정" 시점을 판정한다. 순수 로직이며 **시간을 주입받는다** — 테스트가 실제로 0.6초를 기다리지 않게 하기 위해서다.

**Files:**
- Create: `WordFinder/Features/Camera/Scanning/StabilityDetector.swift`
- Test: `WordFinderTests/StabilityDetectorTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `enum StabilityOutcome: Equatable { case waiting, settled(String), timedOut }`
  - `final class StabilityDetector`
    - `init(stabilityWindow: TimeInterval = 0.6, timeout: TimeInterval = 10, minimumLength: Int = 2)`
    - `func start(at now: TimeInterval)`
    - `func ingest(_ raw: String?, at now: TimeInterval) -> StabilityOutcome`
    - `func reset()`
  - `ingest` 에 `nil` 을 넣으면 "박스 안에 아무것도 안 보임"을 뜻한다.
  - `settled` 가 실어 나르는 문자열은 **정규화된** 값이다.

- [ ] **Step 1: 실패하는 테스트 작성**

`WordFinderTests/StabilityDetectorTests.swift`:

```swift
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
    // 0.5, 9.5, 10.0 은 이진 부동소수점에서 정확히 표현된다. 0.6 / 9.4 를 쓰면
    // 10.0 - 9.4 == 0.5999999999999996 이 되어, 검증하려는 동작과 무관한 이유로
    // 실패한다.
    let detector = StabilityDetector(stabilityWindow: 0.5, timeout: 10)
    detector.start(at: 0)

    #expect(detector.ingest("resilient", at: 9.5) == .waiting)
    #expect(detector.ingest("resilient", at: 10.0) == .settled("resilient"))
}

@Test func resetClearsPreviousProgress() {
    let detector = StabilityDetector(stabilityWindow: 0.6, timeout: 10)
    detector.start(at: 0)
    #expect(detector.ingest("resilient", at: 0.0) == .waiting)

    detector.reset()
    detector.start(at: 100)
    #expect(detector.ingest("resilient", at: 100.5) == .waiting)   // 이전 진행 무효
    #expect(detector.ingest("resilient", at: 101.5) == .settled("resilient"))
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'StabilityDetector' in scope`

- [ ] **Step 3: 구현**

`WordFinder/Features/Camera/Scanning/StabilityDetector.swift`:

```swift
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
```

- [ ] **Step 4: 통과 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, StabilityDetector 테스트 10개 전부 통과

- [ ] **Step 5: 커밋**

```bash
git add WordFinder/Features/Camera/Scanning/StabilityDetector.swift WordFinderTests/StabilityDetectorTests.swift
git commit -m "feat: add StabilityDetector with injected clock"
```

---

### Task 4: ScanViewModel과 TextRecognizer 프로토콜

상태 머신을 만든다. 카메라 없이 완결되며, 가짜 인식기를 주입해 전이를 전부 테스트한다.

**Files:**
- Create: `WordFinder/Features/Camera/Scanning/TextRecognizer.swift`
- Create: `WordFinder/Features/Camera/ScanViewModel.swift`
- Test: `WordFinderTests/ScanViewModelTests.swift`

**Interfaces:**
- Consumes: `StabilityDetector`, `StabilityOutcome`, `WordTokenizer`, `ScannedWord`
- Produces:
  - `@MainActor protocol TextRecognizer: AnyObject`
    - `var onText: ((String?) -> Void)? { get set }`
    - `func startScanning() throws`
    - `func stopScanning()`
    - `static var isSupported: Bool { get }`
  - `enum RecognizerError: Error, Equatable { case unsupportedDevice, permissionDenied }`
  - `enum ScanState: Equatable { case idle(message: String?), scanning(preview: String?), settled([ScannedWord]) }`
  - `@MainActor @Observable final class ScanViewModel`
    - `init(recognizer: TextRecognizer, detector: StabilityDetector = .init(), now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate })`
    - `private(set) var state: ScanState`
    - `func tapScan()`, `func tapCancel()`, `func dismissSheet()`
    - `static let timeoutMessage = "Couldn't read that — try moving closer"`
    - `static let permissionMessage = "Camera access is off. Turn it on in Settings to scan."`
    - `static let unsupportedMessage = "This device can't scan text."`

- [ ] **Step 1: 실패하는 테스트 작성**

`WordFinderTests/ScanViewModelTests.swift`:

```swift
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
        if let startError { throw startError }
        isScanning = true
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
}

@Test @MainActor func unsupportedDeviceShowsItsOwnMessage() {
    let (vm, recognizer, _) = makeSUT()
    recognizer.startError = RecognizerError.unsupportedDevice

    vm.tapScan()
    #expect(vm.state == .idle(message: ScanViewModel.unsupportedMessage))
}
```

`ScannedWord` 는 `id` 가 매번 새 `UUID()` 라 `Equatable` 비교가 안 된다. 다음 단계에서 `term` 기준 `Equatable` 을 추가한다.

- [ ] **Step 2: 실패 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'TextRecognizer' in scope`, `cannot find 'ScanViewModel' in scope`

- [ ] **Step 3: `ScannedWord` 에 term 기준 Equatable 추가**

`WordFinder/Features/Camera/CameraModels.swift` 의 `ScannedWord` 선언을 다음으로 교체한다:

```swift
struct ScannedWord: Identifiable, Equatable {
    let id = UUID()
    let term: String

    /// `id` 는 인스턴스마다 다르므로 단어 자체로 비교한다.
    static func == (lhs: ScannedWord, rhs: ScannedWord) -> Bool {
        lhs.term == rhs.term
    }
}
```

- [ ] **Step 4: TextRecognizer 프로토콜 작성**

`WordFinder/Features/Camera/Scanning/TextRecognizer.swift`:

```swift
import Foundation

enum RecognizerError: Error, Equatable {
    case unsupportedDevice
    case permissionDenied
}

/// 박스 안에 보이는 텍스트를 계속 흘려보내는 인식기.
///
/// 프로토콜로 둔 이유는 두 가지다. 첫째, PLAN.md §8이 비교하라고 한 두 방식
/// (VisionKit `DataScannerViewController` ↔ `AVCaptureSession` + Vision) 을
/// 화면·상태 로직을 건드리지 않고 갈아끼우기 위해서. 둘째, 테스트에서 카메라 없이
/// 가짜를 주입하기 위해서다.
/// `DataScannerViewController` 가 `@MainActor` 격리 타입이므로 프로토콜도 함께
/// 격리한다. 상태 머신과 화면도 모두 메인 액터에서 돈다.
@MainActor
protocol TextRecognizer: AnyObject {
    /// 프레임마다 호출된다. 박스 안에 아무것도 없으면 `nil`.
    var onText: ((String?) -> Void)? { get set }

    func startScanning() throws
    func stopScanning()

    static var isSupported: Bool { get }
}
```

- [ ] **Step 5: ScanViewModel 작성**

`WordFinder/Features/Camera/ScanViewModel.swift`:

```swift
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

    /// 인식기가 콜백을 주지 않아도 타임아웃이 동작하도록 화면이 주기적으로 호출한다.
    /// `DataScannerViewController` 의 델리게이트는 프레임 단위가 아니라 이벤트
    /// 단위여서, 박스 안에 아무것도 없으면 콜백이 아예 오지 않는다.
    func tick() {
        handle(lastText)
    }

    private func stop() {
        recognizer.stopScanning()
        detector.reset()
    }
}
```

- [ ] **Step 6: 통과 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, ScanViewModel 테스트 12개 포함 전체 통과

- [ ] **Step 7: 커밋**

```bash
git add WordFinder/Features/Camera/Scanning/TextRecognizer.swift WordFinder/Features/Camera/ScanViewModel.swift WordFinder/Features/Camera/CameraModels.swift WordFinderTests/ScanViewModelTests.swift
git commit -m "feat: add ScanViewModel state machine behind TextRecognizer protocol"
```

---

### Task 5: DataScannerRecognizer와 SwiftUI 브리지

VisionKit 구현체를 붙인다. **여기부터 실기기가 필요하다** — 시뮬레이터에는 카메라가 없어 `DataScannerViewController` 가 동작하지 않는다.

**Files:**
- Create: `WordFinder/Features/Camera/Scanning/DataScannerRecognizer.swift`
- Create: `WordFinder/Features/Camera/Scanning/ScannerViewRepresentable.swift`

**Interfaces:**
- Consumes: `TextRecognizer`, `RecognizerError`
- Produces:
  - `@MainActor final class DataScannerRecognizer: NSObject, TextRecognizer`
    - `init()`
    - `var regionOfInterest: CGRect?` — 뷰 좌표계. `startScanning()` 전에 넣는다
    - `let controller: DataScannerViewController` — `ScannerViewRepresentable` 이 화면에 얹는다
  - `struct ScannerViewRepresentable: UIViewControllerRepresentable`
    - `init(recognizer: DataScannerRecognizer, regionOfInterest: CGRect)`

- [ ] **Step 1: DataScannerRecognizer 작성**

`WordFinder/Features/Camera/Scanning/DataScannerRecognizer.swift`:

```swift
import Foundation
import VisionKit

/// `TextRecognizer` 의 VisionKit 구현.
///
/// 카메라 세션·초점·연속 인식·프레임 관리가 전부 내장이라 우리가 붙일 코드는
/// 관심 영역 지정과 결과 수신뿐이다. 대신 픽셀 버퍼에 접근할 수 없어 작은 글씨
/// 확대나 대비 보정 같은 전처리는 넣을 수 없다. 인식률이 부족하면
/// `AVCaptureSession` + `VNRecognizeTextRequest` 구현체로 교체한다 (PLAN.md §8).
@MainActor
final class DataScannerRecognizer: NSObject, TextRecognizer {
    var onText: ((String?) -> Void)?

    /// 뷰 좌표계의 가이드 박스. `startScanning()` 호출 전에 설정한다.
    var regionOfInterest: CGRect?

    let controller: DataScannerViewController

    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    override init() {
        controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: false,          // 우리 오버레이를 쓴다
            isHighlightingEnabled: false       // 브래킷을 우리가 그린다
        )
        super.init()
        controller.delegate = self
    }

    func startScanning() throws {
        guard DataScannerViewController.isSupported else {
            throw RecognizerError.unsupportedDevice
        }
        controller.regionOfInterest = regionOfInterest
        do {
            try controller.startScanning()
        } catch DataScannerViewController.ScanningUnavailable.unsupported {
            throw RecognizerError.unsupportedDevice
        } catch {
            // .cameraRestricted 및 권한 거부·화면 잠김 등이 여기로 온다.
            throw RecognizerError.permissionDenied
        }
    }

    func stopScanning() {
        controller.stopScanning()
    }

    /// 박스 안 항목들을 화면 왼쪽→오른쪽 순으로 이어붙인다.
    private func joined(_ items: [RecognizedItem]) -> String? {
        let texts = items
            .compactMap { item -> (CGFloat, String)? in
                guard case .text(let text) = item else { return nil }
                return (text.bounds.topLeft.x, text.transcript)
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)

        return texts.isEmpty ? nil : texts.joined(separator: " ")
    }
}

extension DataScannerRecognizer: DataScannerViewControllerDelegate {
    func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        onText?(joined(allItems))
    }

    func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        onText?(joined(allItems))
    }

    func dataScanner(_ scanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        onText?(joined(allItems))
    }
}
```

- [ ] **Step 2: SwiftUI 브리지 작성**

`WordFinder/Features/Camera/Scanning/ScannerViewRepresentable.swift`:

```swift
import SwiftUI
import VisionKit

/// `DataScannerViewController` 를 SwiftUI 계층에 얹는다. 화면에는 카메라
/// 프리뷰만 보이고, 가이드 박스·블러·브래킷은 `CameraView` 가 이 위에 그린다.
struct ScannerViewRepresentable: UIViewControllerRepresentable {
    let recognizer: DataScannerRecognizer
    let regionOfInterest: CGRect

    func makeUIViewController(context: Context) -> DataScannerViewController {
        recognizer.regionOfInterest = regionOfInterest
        return recognizer.controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        // 회전·레이아웃 변화로 박스 위치가 바뀌면 따라간다.
        recognizer.regionOfInterest = regionOfInterest
        controller.regionOfInterest = regionOfInterest
    }
}
```

- [ ] **Step 3: 시뮬레이터에서 컴파일 확인**

동작은 실기기에서만 확인 가능하지만, 컴파일은 시뮬레이터 빌드로 검증한다.

```bash
xcodebuild -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 기존 테스트가 여전히 통과하는지 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add WordFinder/Features/Camera/Scanning/DataScannerRecognizer.swift WordFinder/Features/Camera/Scanning/ScannerViewRepresentable.swift
git commit -m "feat: add VisionKit DataScanner implementation of TextRecognizer"
```

---

### Task 6: CameraView 연결

가짜 배경과 탭 시뮬레이션을 걷어내고 실제 카메라와 상태 머신을 붙인다. 블러 오버레이·브래킷·topBar는 그대로 살린다.

**Files:**
- Modify: `WordFinder/Features/Camera/CameraView.swift`

**Interfaces:**
- Consumes: `ScanViewModel`, `ScanState`, `DataScannerRecognizer`, `ScannerViewRepresentable`
- Produces: 없음 (최종 소비자)

> **이 태스크에서 정면으로 다뤄야 할 것 (Task 5 리뷰 지적):** `ScannerViewRepresentable`
> 이 구체 타입 `DataScannerRecognizer` 에 묶여 있고 `regionOfInterest` 도 프로토콜이
> 아니라 구체 클래스에 있다. 그래서 이 화면이 구체 타입에 바인딩되고, 나중에
> `AVCaptureSession` 구현으로 갈아끼울 때 화면까지 손대야 한다 — 프로토콜을 둔 이유와
> 반대다. 어떤 카메라 구현이든 자기 프리뷰 뷰를 가져오므로 이음매를 완전히 없앨 수는
> 없다. 최소한 지킬 것: `ScanViewModel` 은 카메라 타입을 전혀 몰라야 하고, 교체 시
> 고쳐야 할 지점이 이 파일 안 한 곳으로 국한돼야 한다.

**`ScanViewModel.swift` 는 수정하지 않는다.** Task 4에서 `recognizer` 를 `TextRecognizer` 프로토콜 타입으로 private 하게 잡아둔 그대로 둔다. 화면이 프리뷰를 얹으려면 구체 타입이 필요한데, 그 인스턴스는 **`CameraView` 가 직접 소유**한다. 그래서 `ScanViewModel` 은 카메라 구현을 계속 모른 채로 남고, Task 4의 테스트 12개가 수정 없이 통과한다.

- [ ] **Step 1: CameraView 교체**

`WordFinder/Features/Camera/CameraView.swift` 전체를 다음으로 교체한다. `GuideMaskShape` 와 `CornerBracketsShape` 는 **파일 하단에 그대로 유지**한다 — 아래 코드에는 생략되어 있으니 기존 정의를 지우지 말 것.

```swift
import SwiftUI

/// 앱의 시작 화면. 셔터가 아니라 연속 라이브 스캔이며, 가이드 박스 밖은 블러 처리된다.
/// Scan 버튼이 인식의 시작을 통제하고, 박스 안 텍스트가 안정되면 자동으로 확정된다.
/// 설계 근거는 `docs/superpowers/specs/2026-08-19-camera-ocr-design.md`.
struct CameraView: View {
    /// 프리뷰를 얹으려면 구체 타입이 필요하므로 화면이 소유한다.
    /// `ScanViewModel` 은 프로토콜 너머로만 이걸 본다.
    @State private var recognizer: DataScannerRecognizer
    @State private var model: ScanViewModel
    @State private var showsSheet = false
    @State private var detailWord: ScannedWord?

    init() {
        let recognizer = DataScannerRecognizer()
        _recognizer = State(initialValue: recognizer)
        _model = State(initialValue: ScanViewModel(recognizer: recognizer))
    }

    private let guideBoxHeight: CGFloat = 38
    private let guideBoxCornerRadius: CGFloat = 4
    /// 가이드 박스의 세로 중심 (화면 높이 비율). 목업 기준이며, 시트가 `.medium`
    /// 으로 올라와도 가리지 않도록 정중앙을 피해 두었다.
    private let guideBoxCenterY: CGFloat = 0.239

    var body: some View {
        GeometryReader { geo in
            let guideWidth = geo.size.width / 2
            let guideRect = CGRect(
                x: (geo.size.width - guideWidth) / 2,
                y: geo.size.height * guideBoxCenterY - guideBoxHeight / 2,
                width: guideWidth,
                height: guideBoxHeight
            )

            ZStack {
                ScannerViewRepresentable(
                    recognizer: recognizer,
                    regionOfInterest: guideRect
                )
                .ignoresSafeArea()

                GuideMaskShape(holeRect: guideRect, cornerRadius: guideBoxCornerRadius)
                    .fill(.ultraThinMaterial, style: FillStyle(eoFill: true))
                    .ignoresSafeArea()

                CornerBracketsShape()
                    .stroke(bracketColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: guideRect.width, height: guideRect.height)
                    .position(x: guideRect.midX, y: guideRect.midY)

                captionView
                    .frame(maxWidth: .infinity)
                    .position(x: geo.size.width / 2, y: guideRect.maxY + 28)

                VStack {
                    topBar
                    Spacer()
                    bottomBar
                }
                .padding(.top, 8)
            }
            .sheet(isPresented: $showsSheet, onDismiss: { model.dismissSheet() }) {
                sheetContent
            }
            .onChange(of: model.state) { _, newState in
                if case .settled = newState { showsSheet = true }
            }
            .task(id: isScanning) {
                // **필수** — `ScanViewModel.tick()` 을 굴리지 않으면 타임아웃이 죽는다.
                // `DataScannerViewController` 의 델리게이트는 이벤트 단위라, 박스 안에
                // 아무것도 없으면 콜백이 아예 오지 않아 `ingest` 가 호출되지 않는다.
                // 빈 벽을 비추는 경우가 정확히 타임아웃이 존재하는 이유다.
                guard isScanning else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    model.tick()
                }
            }
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        if let detailWord {
            WordDetailSheet(detail: CameraMock.detail)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .onDisappear { self.detailWord = nil }
        } else if case .settled(let words) = model.state {
            WordListSheet(words: words) { word in
                detailWord = word
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var isScanning: Bool {
        if case .scanning = model.state { return true }
        return false
    }

    private var bracketColor: Color {
        if case .settled = model.state { return Color.wfAccent }
        return .white.opacity(0.9)
    }

    @ViewBuilder
    private var captionView: some View {
        switch model.state {
        case .idle(let message):
            VStack(spacing: 4) {
                Text(message ?? "Line up a word inside the box")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                if message == nil {
                    Text("Tap Scan when it's in frame")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 32)
        case .scanning(let preview):
            Text(preview ?? "Looking for text…")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .padding(.horizontal, 32)
        case .settled(let words):
            Text("\(words.count) words found in frame")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color(hex: 0x7FD98F))
                    .frame(width: 7, height: 7)
                Text(statusLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.5), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button {
                // TODO: toggle torch via AVCaptureDevice once the real camera session exists
            } label: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.5), in: Circle())
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 20)
    }

    private var statusLabel: String {
        if case .scanning = model.state { return "Scanning · Offline" }
        return "Ready · Offline"
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch model.state {
        case .idle:
            scanButton(title: "Scan", action: model.tapScan)
        case .scanning:
            scanButton(title: "Cancel", action: model.tapCancel)
        case .settled:
            EmptyView()
        }
    }

    private func scanButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentColor, in: Capsule())
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 24)
    }
}

#Preview {
    CameraView()
}
```

- [ ] **Step 2: 시뮬레이터 빌드 확인**

```bash
xcodebuild -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 전체 테스트 통과 확인**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` — Task 4의 12개 테스트가 수정 없이 그대로 통과해야 한다

- [ ] **Step 4: 커밋**

```bash
git add WordFinder/Features/Camera/CameraView.swift
git commit -m "feat: wire CameraView to live camera and scan state machine"
```

---

### Task 7: 실기기 검증과 상수 튜닝

자동화할 수 없는 것들을 실제 기기에서 확인한다. **`Team.xcconfig` 에 본인 Apple Developer Team ID가 필요하다.**

**Files:**
- Modify: `WordFinder/Features/Camera/Scanning/StabilityDetector.swift` (상수 조정 시)
- Modify: `docs/superpowers/specs/2026-08-19-camera-ocr-design.md` (결과 기록)

**Interfaces:**
- Consumes: 앞선 모든 태스크
- Produces: 없음

- [ ] **Step 1: 실기기 빌드 준비**

```bash
# Team.xcconfig의 DEVELOPMENT_TEAM을 본인 Team ID로 수정한 뒤
xcodegen generate
```

Xcode에서 프로젝트를 열고 기기를 선택해 실행한다. 무선으로 하려면 케이블로 한 번 연결한 뒤 Xcode → Window → Devices and Simulators → 기기 선택 → **Connect via network** 를 켜면 이후 케이블 없이 된다.

- [ ] **Step 2: 권한 흐름 확인**

앱을 처음 설치하고 실행한다. 기대 동작:
- 앱 실행 시점에는 권한 요청이 뜨지 **않는다**
- Scan을 처음 누를 때 권한 요청이 뜬다
- 거부하면 `"Camera access is off. Turn it on in Settings to scan."` 이 캡션에 뜬다

거부 상태를 다시 만들려면 설정 → WordFinder → 카메라를 끄거나, 앱을 삭제하고 재설치한다.

- [ ] **Step 3: 실제 인식률 측정**

원서 3권 × 조명 3조건(밝은 실내 / 어두운 실내 / 야외)으로 각각 5회 스캔한다. 기록할 것:
- 확정까지 걸린 체감 시간
- 잘못 읽은 비율
- 타임아웃(10초)에 걸린 횟수

PLAN.md §10의 0주차 PoC 첫 과제가 이것이다.

- [ ] **Step 4: 상수 튜닝**

Step 3 결과로 `StabilityDetector` 의 기본값을 조정한다.
- 확정이 너무 빨라 잘못 읽은 값이 확정되면 → `stabilityWindow` 를 0.8~1.0으로 올린다
- 확정이 안 돼 답답하면 → 0.4로 내린다
- 10초가 너무 길게 느껴지면 → `timeout` 을 7초로 내린다

값을 바꿨다면 Task 3의 테스트는 명시적 인자를 넘기므로 그대로 통과한다. 기본값만 바뀐다.

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 스캔 버튼 존폐 판단과 스펙 갱신**

설계 문서 §8에 적힌 대로, 스캔 버튼은 PLAN.md §2 v4의 연속 스캔 UX와 어긋난다. 실기기에서 써본 뒤 결정한다.
- **유지** → PLAN.md §2·§7과 디자인 목업을 갱신해야 한다는 항목을 스펙 §8에 남긴다
- **제거** → 별도 태스크로 처리한다. 이 계획에서는 하지 않는다

스펙 문서 §8 끝에 실기기 검증 결과와 결정을 덧붙인다.

- [ ] **Step 6: 커밋**

```bash
git add WordFinder/Features/Camera/Scanning/StabilityDetector.swift docs/superpowers/specs/2026-08-19-camera-ocr-design.md
git commit -m "tune: adjust stability constants from on-device testing"
```

---

### Task 8: 마무리 — CLAUDE.md 갱신과 PR

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: 앞선 모든 태스크
- Produces: 없음

- [ ] **Step 1: CLAUDE.md의 placeholder 목록 갱신**

`## Current placeholders` 섹션의 첫 두 항목을 다음으로 교체한다:

```markdown
- **Camera/OCR**: wired up — `DataScannerRecognizer` (VisionKit) feeds
  `ScanViewModel` through the `TextRecognizer` protocol. Swap that protocol's
  implementation, not the view, if accuracy forces a move to
  `AVCaptureSession` + Vision (PLAN.md §8).
- **Dictionary data**: `CameraModels.swift` still has hardcoded mock content
  ("resilient") for `WordDetailSheet`. The *word list* is real OCR output now;
  the *definitions* are not. No dictionary API call exists yet.
- **Word tokenization**: `WordTokenizer` splits on whitespace client-side as a
  stopgap. PLAN.md F4 puts tokenization and lemmatization on the server —
  delete that file when the server lands.
```

`## Build & workflow commands` 섹션 끝에 테스트 명령을 추가한다:

```markdown
Run tests (Swift Testing):

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The `CoreData: error:` lines in the output are noise from the test host app
booting SwiftData — look for `** TEST SUCCEEDED **`.
```

그리고 `**There is no test target.**` 로 시작하는 단락을 삭제한다 — 더 이상 사실이 아니다.

- [ ] **Step 2: 전체 검증**

```bash
xcodebuild test -project WordFinder.xcodeproj -scheme WordFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: 커밋과 푸시**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for camera OCR and test target"
git push -u origin feat/camera-ocr
```

- [ ] **Step 4: PR 생성**

```bash
gh pr create --base main --head feat/camera-ocr \
  --title "feat: 카메라 OCR 1단계 — 실제 인식된 단어 목록" \
  --body "설계: docs/superpowers/specs/2026-08-19-camera-ocr-design.md

CameraMock의 하드코딩된 단어 4개를 실제 Vision OCR 결과로 교체했습니다.

- VisionKit DataScannerViewController를 TextRecognizer 프로토콜 뒤에 격리
- Scan 버튼으로 인식 시작(게이트), 텍스트 0.6초 안정 시 자동 확정
- 10초 타임아웃 + 안내 문구
- 카메라 권한은 최초 Scan 탭 시 요청
- 테스트 타겟 신설, 순수 로직은 시간 주입으로 전부 유닛 테스트

스캔 버튼은 PLAN.md §2 v4의 연속 스캔 UX와 어긋납니다. 설계 문서 §8에 근거와
재검토 조건을 기록했습니다."
```

---

## 실행 순서 메모

Task 1~4는 **시뮬레이터만으로 완결**된다. Task 5부터 실기기가 필요하다. 실기기 준비가 늦어지면 Task 4까지 먼저 머지하고 Task 5~8을 후속 PR로 나눠도 된다 — Task 4까지만으로도 상태 머신과 순수 로직이 전부 테스트된 상태가 된다.
