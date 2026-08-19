import SwiftUI

/// Stage 2 of the result sheet: full word detail, reached by tapping a row in
/// `WordListSheet`. The camera keeps scanning behind it — "Keep scanning" and the
/// close button both just dismiss back to the live viewfinder.
struct WordDetailSheet: View {
    let detail: WordDetailPreview

    @Environment(\.dismiss) private var dismiss
    @State private var isPlayingAudio = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                definitions
                capturedContext
                footer
            }
        }
        .background(Color.wfBackground)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(detail.term)
                    .font(.wfHeadwordSheet)
                    .foregroundStyle(Color.wfTextPrimary)
                HStack(spacing: 12) {
                    Text(detail.phonetic)
                        .font(.wfIPA)
                        .foregroundStyle(Color.wfTextSecondary)
                    Button {
                        isPlayingAudio.toggle()
                        // TODO: dictionary audio URL, falling back to AVSpeechSynthesizer (F6)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(isPlayingAudio ? Color.wfBackground : Color.accentColor)
                            .frame(width: 34, height: 34)
                            .background(isPlayingAudio ? Color.accentColor : Color.wfPrimaryTint, in: Circle())
                    }
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var definitions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(detail.partOfSpeech.uppercased())
                    .font(.wfPOSLabel)
                    .tracking(0.8)
                    .foregroundStyle(Color.accentColor)
                Rectangle().fill(Color.wfSeparator).frame(height: 1)
            }

            ForEach(Array(detail.definitions.enumerated()), id: \.element.id) { index, def in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.wfDefinition)
                        .foregroundStyle(Color.wfTextSecondary)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(def.text)
                            .font(.wfDefinition)
                            .foregroundStyle(Color.wfTextPrimary)
                        if let example = def.example {
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

            if !detail.synonyms.isEmpty {
                synonymChips
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var synonymChips: some View {
        HStack(spacing: 8) {
            Text("Synonyms")
                .font(.system(size: 13))
                .foregroundStyle(Color.wfTextSecondary)
            ForEach(detail.synonyms, id: \.self) { synonym in
                Text(synonym)
                    .font(.wfWordRow)
                    .foregroundStyle(Color.wfTextPrimary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Color.wfPrimaryTint, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var capturedContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CAPTURED CONTEXT")
                .font(.wfPOSLabel)
                .tracking(0.8)
                .foregroundStyle(Color.wfTextSecondary)
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.wfSeparator.opacity(0.4))
                    .frame(width: 64, height: 64)
                highlightedContext
            }
            Text("Today · Camera")
                .font(.wfCaption)
                .foregroundStyle(Color.wfTextSecondary)
        }
        .padding(14)
        .background(Color.wfSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wfSeparator, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private var highlightedContext: some View {
        let text = detail.capturedContext
        return Group {
            if let range = text.range(of: detail.highlightedTerm) {
                let before = String(text[text.startIndex..<range.lowerBound])
                let highlighted = String(text[range])
                let after = String(text[range.upperBound...])
                (
                    Text("“\(before)")
                        + Text(highlighted).foregroundColor(Color.wfTextPrimary).underline(true, color: Color.accentColor)
                        + Text("\(after)”")
                )
                .font(.wfExample)
                .foregroundStyle(Color.wfTextSecondary)
            } else {
                Text("“\(text)”")
                    .font(.wfExample)
                    .foregroundStyle(Color.wfTextSecondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Saved to History · \(detail.source)")
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
}

#Preview {
    WordDetailSheet(detail: CameraMock.detail)
}
