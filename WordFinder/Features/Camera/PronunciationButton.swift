import SwiftUI

/// 표제어를 소리로 읽는 버튼.
///
/// 상세 시트와 폴백 화면 **양쪽**에서 쓴다. TTS 는 사전 응답이 필요 없고 표제어만 있으면
/// 되므로, 온라인 사전이 실패해 Apple 내장 사전으로 넘어간 화면에서도 똑같이 동작한다.
/// 오히려 그쪽이 더 중요하다 — 흔한 단어만 빠르게 응답하는 지금 상황에서, 모르는 단어일수록
/// 폴백으로 갈 확률이 높기 때문이다.
struct PronunciationButton: View {
    let term: String
    let player: PronunciationPlayer

    var body: some View {
        Button {
            player.toggle(term)
        } label: {
            Image(systemName: player.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.system(size: 15))
                .foregroundStyle(player.isSpeaking ? Color.accentColor : Color.wfTextSecondary)
                // 터치 영역은 44×44, 보이는 아이콘은 15pt 다. 부르는 쪽이 음수 패딩으로 여백을
                // 상쇄해도 탭은 44 전체에서 받는다 — 시뮬레이터에서 아이콘 중심에서 20pt
                // 떨어진 지점을 눌러 확인했다. 설계 문서 §13 이 닫기 버튼(30×30)을 권장치
                // 미달로 지적했으므로 새 버튼에서 같은 실수를 반복하지 않는다.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(player.isSpeaking ? "Stop pronunciation" : "Play pronunciation")
    }
}
