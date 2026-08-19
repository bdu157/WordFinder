import Foundation
import SwiftData

/// One search event; the same term can appear multiple times as separate history rows (see PLAN.md §6).
@Model
final class HistoryRecord {
    var entry: DictEntryRecord?
    var searchedAt: Date
    var origin: String
    var imagePath: String?
    var contextText: String?

    init(entry: DictEntryRecord, searchedAt: Date, origin: String, imagePath: String? = nil, contextText: String? = nil) {
        self.entry = entry
        self.searchedAt = searchedAt
        self.origin = origin
        self.imagePath = imagePath
        self.contextText = contextText
    }
}
