import AVFoundation

/// `AVSpeechSynthesizer` 어댑터. `SpeechSynthesizing` 의 유일한 실제 구현이다.
///
/// `NSObject` 를 상속하는 이유는 `AVSpeechSynthesizerDelegate` 가 요구하기 때문이다. 그래서
/// 이 요구를 프로토콜 쪽으로 올리지 않고, 종료 통지를 `onFinish` 클로저로 바꿔 내보낸다.
///
/// 여기에는 테스트가 없다. 플랫폼 접착 코드이고, 로직은 전부 `PronunciationPlayer` 에 있다.
@MainActor
final class SystemSpeechSynthesizer: NSObject, SpeechSynthesizing {
    var onFinish: (() -> Void)?

    /// 영영사전이므로 미국 영어로 읽는다. 사용자가 고를 수 있게 하는 것은 PLAN.md §7 의
    /// 설정 항목이며 아직 구현하지 않았다.
    static let language = "en-US"

    private let synthesizer = AVSpeechSynthesizer()

    /// 지금 재생 중인 발화. **델리게이트 콜백을 거르는 데 쓴다.**
    ///
    /// `stopSpeaking` 은 즉시 돌아오지만 `didCancel` 은 한 박자 뒤에 온다. 그 사이에 다음
    /// 발화가 시작되면, 뒤늦게 도착한 **지난 발화의** 콜백이 새 발화의 오디오 세션을 끄고
    /// `onFinish` 를 쏴 버린다. 그러면 소리는 나는데 버튼은 멈춘 것처럼 보인다.
    /// 콜백으로 받은 발화가 이 값과 같을 때만 처리해서 그 경로를 막는다.
    private var activeUtterance: AVSpeechUtterance?

    /// 오디오 세션을 켠 채로 두면 다른 앱 소리가 계속 눌린다. 되돌리기 위해 지금 켜 둔
    /// 상태인지 기억한다.
    private var holdsAudioSession = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.language)
        // 속도는 시스템 기본값을 쓴다. 단어 하나를 읽는 용도라 더 늦추는 게 나을 수 있지만,
        // 들어 보지 않고 숫자를 정하면 근거 없는 상수가 남는다. 실기기에서 들어 본 뒤 조정한다.

        // 멈추기 **전에** 새 발화를 현재 발화로 등록한다. 그래야 바로 아래 `stopSpeaking` 이
        // 유발하는 지난 발화의 `didCancel` 이 걸러진다.
        activeUtterance = utterance
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        activateAudioSession()
        synthesizer.speak(utterance)
    }

    /// 호출한 쪽이 이미 상태를 내렸으므로 `onFinish` 를 쏘지 않는다 (`SpeechSynthesizing` 의 약속).
    /// 세션도 콜백을 기다리지 않고 여기서 바로 되돌린다 — `.immediate` 라 이미 소리가 멎었고,
    /// 콜백을 기다리면 그 사이에 화면이 사라져 세션이 영영 활성으로 남을 수 있다.
    func stop() {
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        releaseAudioSession()
    }

    /// 무음 스위치가 켜져 있으면 기본 카테고리의 소리는 나지 않는다. 🔊 는 사용자가 명시적으로
    /// 누른 요청이므로 `.playback` 으로 올려 무음에서도 들리게 한다. `.duckOthers` 를 함께 주어
    /// 듣고 있던 음악을 끊지 않고 잠깐 줄이기만 한다.
    private func activateAudioSession() {
        guard !holdsAudioSession else { return }
        let session = AVAudioSession.sharedInstance()
        // 세션 설정이 실패해도 말은 나올 수 있으므로 던지지 않고 넘어간다. 실패하면 무음
        // 스위치가 켜진 기기에서 소리가 안 나는 정도의 손실이다.
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            holdsAudioSession = true
        } catch {
            holdsAudioSession = false
        }
    }

    /// 다른 앱 소리를 원래 크기로 돌려놓는다.
    private func releaseAudioSession() {
        guard holdsAudioSession else { return }
        holdsAudioSession = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// 저절로 끝난 발화만 여기로 들어온다. 지난 발화의 뒤늦은 콜백은 버린다.
    fileprivate func handleSpeechEnded(_ utterance: AVSpeechUtterance) {
        guard utterance === activeUtterance else { return }
        activeUtterance = nil
        releaseAudioSession()
        onFinish?()
    }
}

extension SystemSpeechSynthesizer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in handleSpeechEnded(utterance) }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in handleSpeechEnded(utterance) }
    }
}
