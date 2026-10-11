import SwiftUI

/// 단어 목록에서 누른 단어의 상세 시트. 조회 상태에 따라 세 화면 중 하나를 보여준다.
///
/// 불러오는 중 → 누른 단어 + 스피너 · 성공 → `WordDetailSheet` ·
/// 실패 → 안내 한 줄 + Apple 내장 사전 (설계 문서 `2026-09-21-word-lookup-design.md` §4, §7).
struct WordLookupView: View {
    @State private var model: WordLookupModel
    /// 발음 재생을 **여기서** 소유한다. 성공·실패 어느 화면으로 가든 같은 플레이어를 쓰고,
    /// 멈추는 곳도 아래 `.onDisappear` 한 곳뿐이다. 상태가 바뀌어 화면이 갈려도 말이 이어지지
    /// 않도록, 소유를 두 화면보다 위에 둔다.
    @State private var player = PronunciationPlayer(synthesizer: SystemSpeechSynthesizer())

    init(term: String, service: DictionaryService = DictionaryAPIClient.shared) {
        _model = State(initialValue: WordLookupModel(term: term, service: service))
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                loadingView
            case .loaded(let entry):
                WordDetailSheet(entry: entry, player: player)
            case .fallback:
                fallbackView
            }
        }
        .task { await model.load() }
        // **필수** — 시트를 닫거나 다른 단어로 넘어갈 때 말을 멈춘다. 빠뜨리면 화면이 사라진
        // 뒤에도 소리가 이어지고, 오디오 세션이 활성인 채 남아 다른 앱 음악이 줄어든 상태로
        // 방치된다. `AVSpeechSynthesizer` 의 델리게이트는 weak 이라, 이 뷰가 해제되고 나면
        // 종료 콜백이 오지 않아 세션을 되돌릴 기회가 영영 없다.
        .onDisappear { player.stop() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Text(model.term)
                .font(.wfHeadwordSheet)
                .foregroundStyle(Color.wfTextPrimary)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wfBackground)
    }

    /// 안내 없이 Apple 화면만 띄우면 사용자는 모양이 갑자기 달라진 이유를 모른다.
    ///
    /// 안내 띠에 🔊 를 함께 둔다. Apple 사전 뷰(`UIReferenceLibraryViewController`)는 우리가
    /// 내용을 바꿀 수 없고, 사용자가 실제로 이 화면을 더 자주 본다. 사전 조회가 실패했을 뿐
    /// 읽을 표제어는 그대로 있으므로 발음은 여기서도 동작해야 한다.
    private var fallbackView: some View {
        VStack(spacing: 0) {
            if let notice = model.fallbackNotice {
                HStack(spacing: 8) {
                    Text(notice)
                        .font(.wfCaption)
                        .foregroundStyle(Color.wfTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // 44 프레임이 만든 세로 여백을 상쇄해 안내 띠가 두꺼워지지 않게 한다.
                    PronunciationButton(term: model.term, player: player)
                        .padding(.vertical, -14)
                        .padding(.trailing, -14)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.wfPrimaryTint)
            }
            SystemDictionaryView(term: model.term)
        }
    }
}
