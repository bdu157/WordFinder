import Foundation
import Observation

/// 단어를 소리로 내는 쪽.
///
/// `AVSpeechSynthesizer` 를 직접 쓰지 않고 프로토콜로 끊는 이유는 `DictionaryService` 와 같다 —
/// 테스트가 실제로 스피커를 울리지 않아야 한다. 구체 구현은 `SystemSpeechSynthesizer` 하나뿐이다.
@MainActor
protocol SpeechSynthesizing: AnyObject {
    /// 말하기 시작한다. 이미 말하는 중이면 멈추고 새로 시작한다.
    func speak(_ text: String)
    func stop()

    /// 말이 **저절로 끝났을 때만** 호출된다. `stop()` 으로 멈춘 경우에는 호출되지 않는다.
    ///
    /// 구현체가 이 약속을 지켜야 한다. 취소 통지가 한 박자 늦게 와서, 그 사이에 시작된
    /// 다음 발화의 상태를 덮어쓰는 사고를 막기 위한 것이다.
    ///
    /// 델리게이트를 그대로 노출하지 않고 클로저로 둔 이유: `AVSpeechSynthesizerDelegate` 는
    /// `NSObject` 를 요구해서, 그걸 프로토콜에 올리면 가짜도 `NSObject` 가 되어야 한다.
    var onFinish: (() -> Void)? { get set }
}

/// 🔊 버튼의 상태. 지금 말하는 중인지만 들고 있으면 되므로 열거형이 필요하지 않다.
///
/// 어떤 단어를 말하는지는 기억하지 않는다. 상세 시트는 한 번에 한 단어만 보여주고,
/// 다른 단어를 누르면 `CameraView` 가 `.id(detailWord.term)` 으로 시트를 다시 만들기 때문이다.
@MainActor
@Observable
final class PronunciationPlayer {
    private(set) var isSpeaking = false

    private let synthesizer: SpeechSynthesizing

    init(synthesizer: SpeechSynthesizing) {
        self.synthesizer = synthesizer
        self.synthesizer.onFinish = { [weak self] in
            self?.isSpeaking = false
        }
    }

    /// 말하고 있지 않으면 말하고, 말하는 중이면 멈춘다.
    ///
    /// 같은 버튼이 재생과 정지를 겸한다 — 단어 하나는 1초 안에 끝나므로 정지 버튼을 따로
    /// 두면 거의 눌릴 일이 없다.
    func toggle(_ term: String) {
        if isSpeaking {
            stop()
        } else {
            synthesizer.speak(term)
            isSpeaking = true
        }
    }

    /// 말하는 중이면 멈춘다.
    ///
    /// 화면이 사라질 때 반드시 불러야 한다. 그러지 않으면 시트를 닫은 뒤에도 소리가 계속 나고,
    /// 더 나쁘게는 오디오 세션이 활성인 채 남아 다른 앱 음악이 줄어든 상태로 방치된다.
    func stop() {
        guard isSpeaking else { return }
        synthesizer.stop()
        isSpeaking = false
    }
}
