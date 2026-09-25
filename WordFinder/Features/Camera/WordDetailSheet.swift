import SwiftUI

/// 단어 상세 — 사전 항목 하나를 보여준다. `WordLookupView` 가 조회에 성공했을 때 뜬다.
///
/// 레이아웃은 Claude Design 목업을 따른다. 가짜 데이터를 전제로 했던 부분 — 발음 버튼,
/// Captured Context 카드, "Saved to History" 문구 — 은 설계 문서
/// `2026-09-21-word-lookup-design.md` §5 에 따라 뺐다. 발음과 히스토리는 다음 단계에서 되살린다.
struct WordDetailSheet: View {
    let entry: DictEntry

    /// 품사마다 처음에 보여줄 뜻의 개수. `running` 의 동사 뜻은 34개다.
    static let initialDefinitionCount = 3

    @Environment(\.dismiss) private var dismiss
    @State private var expandedPartsOfSpeech: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                // 매퍼가 같은 품사를 하나로 합치므로 품사가 식별자로 유일하다.
                ForEach(entry.meanings, id: \.partOfSpeech) { meaning in
                    meaningSection(meaning)
                }
                footer
            }
        }
        .background(Color.wfBackground)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.term)
                    .font(.wfHeadwordSheet)
                    .foregroundStyle(Color.wfTextPrimary)
                // 발음기호가 없는 단어가 실제로 있다 (resilient).
                if let phonetic = entry.phonetic {
                    Text(phonetic)
                        .font(.wfIPA)
                        .foregroundStyle(Color.wfTextSecondary)
                }
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.wfTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.wfPrimaryTint, in: Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func meaningSection(_ meaning: DictEntry.Meaning) -> some View {
        let isExpanded = expandedPartsOfSpeech.contains(meaning.partOfSpeech)
        let visible = isExpanded
            ? meaning.definitions
            : Array(meaning.definitions.prefix(Self.initialDefinitionCount))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(meaning.partOfSpeech.uppercased())
                    .font(.wfPOSLabel)
                    .tracking(0.8)
                    .foregroundStyle(Color.accentColor)
                Rectangle().fill(Color.wfSeparator).frame(height: 1)
            }

            ForEach(Array(visible.enumerated()), id: \.offset) { index, definition in
                definitionRow(number: index + 1, definition: definition)
            }

            if visible.count < meaning.definitions.count {
                Button("Show all \(meaning.definitions.count)") {
                    expandedPartsOfSpeech.insert(meaning.partOfSpeech)
                }
                .font(.system(size: 15, weight: .medium))
                .tint(Color.accentColor)
            }

            if let synonyms = meaning.synonyms {
                synonymChips(synonyms)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private func definitionRow(number: Int, definition: DictEntry.Definition) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.wfDefinition)
                .foregroundStyle(Color.wfTextSecondary)
            VStack(alignment: .leading, spacing: 10) {
                Text(definition.definition)
                    .font(.wfDefinition)
                    .foregroundStyle(Color.wfTextPrimary)
                if let example = definition.example {
                    Text(example)
                        .font(.wfExample)
                        .foregroundStyle(Color.wfTextSecondary)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color.wfSeparator).frame(width: 2)
                        }
                }
            }
        }
    }

    /// 동의어가 많으면 가로로 넘친다 — 줄바꿈 대신 가로 스크롤로 한 줄을 지킨다.
    private func synonymChips(_ synonyms: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Synonyms")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.wfTextSecondary)
                ForEach(synonyms, id: \.self) { synonym in
                    Text(synonym)
                        .font(.wfWordRow)
                        .foregroundStyle(Color.wfTextPrimary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Color.wfPrimaryTint, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            // 출처 표기는 라이선스 의무다 (dictionaryapi.dev 는 CC BY-SA).
            Text("Definitions: \(sourceAttribution)")
                .font(.wfCaption)
                .foregroundStyle(Color.wfTextSecondary)
            Spacer()
            Button("Keep scanning") { dismiss() }
                .font(.system(size: 15, weight: .medium))
                .tint(Color.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var sourceAttribution: String {
        switch entry.source {
        case .dictionaryapi: return "dictionaryapi.dev (CC BY-SA)"
        case .mwLearners: return "Merriam-Webster Learner's"
        case .oxford: return "Oxford"
        }
    }
}

#if DEBUG
extension DictEntry {
    /// 프리뷰 전용. 실제 응답(`resilient`)처럼 발음기호가 없고 동의어가 품사 단위에만 있다.
    static let previewResilient = DictEntry(
        term: "resilient", lang: "en", type: .word, phonetic: nil,
        audioUrl: "https://api.dictionaryapi.dev/media/pronunciations/en/resilient-us.mp3",
        meanings: [DictEntry.Meaning(
            partOfSpeech: "adjective",
            definitions: [
                DictEntry.Definition(
                    definition: "(of objects or substances) Returning quickly to original shape after force is applied; elastic.",
                    example: nil, synonyms: nil),
                DictEntry.Definition(
                    definition: "(organisms or people, of systems) Returning quickly to normal after damaging events or conditions.",
                    example: nil, synonyms: nil),
            ],
            synonyms: ["bendable", "flexible", "strong"]
        )],
        source: .dictionaryapi, fetchedAt: 0
    )
}

#Preview {
    WordDetailSheet(entry: .previewResilient)
}
#endif
