import Foundation
import SwiftData

/// Local cache of a looked-up dictionary entry, keyed by normalized term (see PLAN.md §6).
@Model
final class DictEntryRecord {
    @Attribute(.unique) var term: String
    var lang: String = "en"
    var type: String
    var payloadJSON: String
    var source: String?
    var fetchedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HistoryRecord.entry)
    var historyItems: [HistoryRecord] = []

    init(term: String, type: String, payloadJSON: String, source: String?, fetchedAt: Date) {
        self.term = term
        self.type = type
        self.payloadJSON = payloadJSON
        self.source = source
        self.fetchedAt = fetchedAt
    }
}
