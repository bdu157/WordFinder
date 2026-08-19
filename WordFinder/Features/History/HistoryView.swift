import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \HistoryRecord.searchedAt, order: .reverse) private var history: [HistoryRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""

    private var filteredHistory: [HistoryRecord] {
        guard !searchText.isEmpty else { return history }
        return history.filter {
            $0.entry?.term.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    private var groupedByDay: [(label: String, items: [HistoryRecord])] {
        let groups = Dictionary(grouping: filteredHistory) { Calendar.current.startOfDay(for: $0.searchedAt) }
        return groups.keys.sorted(by: >).map { day in
            (label: dayLabel(for: day), items: groups[day] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if filteredHistory.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No words yet",
                        systemImage: "clock",
                        description: Text("Words you scan will show up here.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(groupedByDay, id: \.label) { group in
                                sectionCard(label: group.label, items: group.items)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color.wfBackground)
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.wfTextPrimary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.wfTextSecondary)
                TextField("Search words", text: $searchText)
                    .foregroundStyle(Color.wfTextPrimary)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.wfPrimaryTint, in: RoundedRectangle(cornerRadius: 11))

            Text("\(history.count) words · available offline")
                .font(.system(size: 13))
                .foregroundStyle(Color.wfTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func sectionCard(label: String, items: [HistoryRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.wfTextSecondary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(for: item)
                    if index != items.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color.wfSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wfSeparator, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    private func row(for item: HistoryRecord) -> some View {
        HStack(spacing: 12) {
            StripedThumbnail()
                .frame(width: 44, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.entry?.term ?? "—")
                    .font(.wfWordRow)
                    .foregroundStyle(Color.wfTextPrimary)
                if let context = item.contextText {
                    Text(context)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.wfTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(item.searchedAt, format: .dateTime.hour().minute())
                .font(.system(size: 13))
                .foregroundStyle(Color.wfTextSecondary.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .swipeActions {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.month().day())
    }
}

/// Lightweight stand-in for a scan crop thumbnail until real crop images exist.
private struct StripedThumbnail: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.wfSeparator.opacity(0.5)))
            let spacing: CGFloat = 6
            var x = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(path, with: .color(Color.wfSurface.opacity(0.6)), lineWidth: 3)
                x += spacing
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [DictEntryRecord.self, HistoryRecord.self], inMemory: true)
}
