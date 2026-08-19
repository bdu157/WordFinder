import SwiftUI
import SwiftData

@main
struct WordFinderApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [DictEntryRecord.self, HistoryRecord.self])
    }
}
