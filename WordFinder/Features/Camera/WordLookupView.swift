import SwiftUI

/// 단어 목록에서 누른 단어의 상세 시트. 조회 상태에 따라 세 화면 중 하나를 보여준다.
///
/// 불러오는 중 → 누른 단어 + 스피너 · 성공 → `WordDetailSheet` ·
/// 실패 → 안내 한 줄 + Apple 내장 사전 (설계 문서 `2026-09-21-word-lookup-design.md` §4, §7).
struct WordLookupView: View {
    @State private var model: WordLookupModel

    init(term: String, service: DictionaryService = DictionaryAPIClient.shared) {
        _model = State(initialValue: WordLookupModel(term: term, service: service))
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                loadingView
            case .loaded(let entry):
                WordDetailSheet(entry: entry)
            case .fallback:
                fallbackView
            }
        }
        .task { await model.load() }
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
    private var fallbackView: some View {
        VStack(spacing: 0) {
            if let notice = model.fallbackNotice {
                Text(notice)
                    .font(.wfCaption)
                    .foregroundStyle(Color.wfTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.wfPrimaryTint)
            }
            SystemDictionaryView(term: model.term)
        }
    }
}
