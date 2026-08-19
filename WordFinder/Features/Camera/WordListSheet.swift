import SwiftUI

/// Stage 1 of the result sheet: recognized words as a plain list — no dictionary
/// lookup yet. Tapping a row expands the sheet into `WordDetailSheet` (stage 2).
struct WordListSheet: View {
    let words: [ScannedWord]
    var onSelect: (ScannedWord) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Words found")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.wfTextPrimary)
                    Text("Tap a word to look it up")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.wfTextSecondary)
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
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                    Button {
                        onSelect(word)
                    } label: {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(index == 0 ? Color.accentColor : .clear)
                                .frame(width: 3)
                            Text(word.term)
                                .font(.wfWordRow)
                                .fontWeight(index == 0 ? .semibold : .regular)
                                .foregroundStyle(Color.wfTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(index == 0 ? Color.accentColor : Color.wfSeparator)
                        }
                        .padding(.trailing, 14)
                        .frame(minHeight: 56)
                        .background(index == 0 ? Color.wfPrimaryTint : Color.clear)
                    }
                    .buttonStyle(.plain)

                    if word.id != words.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color.wfSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 8)
        .background(Color.wfBackground)
    }
}

#Preview {
    WordListSheet(words: CameraMock.recognizedWords) { _ in }
}
