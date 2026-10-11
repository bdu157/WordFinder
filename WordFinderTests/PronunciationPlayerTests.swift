import Foundation
import Testing

@testable import WordFinder

/// 실제로 소리를 내지 않는 가짜. `AVSpeechSynthesizer` 를 직접 쓰면 테스트가 스피커를 울려야 한다.
@MainActor
private final class FakeSynthesizer: SpeechSynthesizing {
    var onFinish: (() -> Void)?

    private(set) var spokenTexts: [String] = []
    private(set) var stopCount = 0

    func speak(_ text: String) {
        spokenTexts.append(text)
    }

    func stop() {
        stopCount += 1
    }

    /// 실제 synthesizer 가 말을 끝냈을 때 델리게이트로 알리는 것을 흉내낸다.
    func finishSpeaking() {
        onFinish?()
    }
}

@MainActor
@Suite("PronunciationPlayer")
struct PronunciationPlayerTests {
    @Test("처음에는 말하고 있지 않다")
    func startsSilent() {
        let player = PronunciationPlayer(synthesizer: FakeSynthesizer())

        #expect(player.isSpeaking == false)
    }

    @Test("누르면 그 단어를 말하고 isSpeaking 이 참이 된다")
    func togglePlaysTheTerm() {
        let fake = FakeSynthesizer()
        let player = PronunciationPlayer(synthesizer: fake)

        player.toggle("resilient")

        // 누른 단어를 그대로 넘기는지 본다. 하드코딩된 문자열을 말해도 통과하면 안 되므로
        // 단어 자체를 확인한다.
        #expect(fake.spokenTexts == ["resilient"])
        #expect(player.isSpeaking == true)
    }

    @Test("말하는 중에 다시 누르면 멈춘다 — 다시 말하지 않는다")
    func toggleWhileSpeakingStops() {
        let fake = FakeSynthesizer()
        let player = PronunciationPlayer(synthesizer: fake)

        player.toggle("resilient")
        player.toggle("resilient")

        #expect(fake.stopCount == 1)
        #expect(player.isSpeaking == false)
        // 두 번째 탭이 정지여야 하므로 말한 횟수는 늘지 않는다.
        #expect(fake.spokenTexts == ["resilient"])
    }

    @Test("말이 저절로 끝나면 isSpeaking 이 거짓으로 돌아간다")
    func finishingClearsSpeakingState() {
        let fake = FakeSynthesizer()
        let player = PronunciationPlayer(synthesizer: fake)

        player.toggle("resilient")
        fake.finishSpeaking()

        #expect(player.isSpeaking == false)
        // 끝난 뒤 다시 누르면 멈추는 게 아니라 말해야 한다.
        player.toggle("resilient")
        #expect(fake.spokenTexts == ["resilient", "resilient"])
        #expect(fake.stopCount == 0)
    }

    @Test("stop 은 말하는 중일 때 멈춘다 — 화면이 사라질 때 쓰는 경로")
    func stopHaltsSpeech() {
        let fake = FakeSynthesizer()
        let player = PronunciationPlayer(synthesizer: fake)

        player.toggle("resilient")
        player.stop()

        #expect(fake.stopCount == 1)
        #expect(player.isSpeaking == false)
    }

    @Test("stop 은 말하고 있지 않으면 아무것도 하지 않는다")
    func stopIsAnoOpWhenSilent() {
        let fake = FakeSynthesizer()
        let player = PronunciationPlayer(synthesizer: fake)

        player.stop()

        // `onDisappear` 는 말하지 않는 상태에서도 매번 불린다. 그래서 `stop` 은 멱등이어야
        // 하고, 조용할 때 신시사이저를 쓸데없이 건드리지 않아야 한다.
        #expect(fake.stopCount == 0)
        #expect(player.isSpeaking == false)
    }

    @Test("끝난 뒤 다른 단어를 누르면 그 단어를 말한다")
    func playsADifferentTermAfterFinishing() {
        let fake = FakeSynthesizer()
        let player = PronunciationPlayer(synthesizer: fake)

        player.toggle("resilient")
        fake.finishSpeaking()
        player.toggle("urban")

        #expect(fake.spokenTexts == ["resilient", "urban"])
    }
}
