import Foundation
import SwiftData

// Represents a single completed work block stored persistently.
// SwiftData uses the @Model macro to generate all persistence boilerplate.
@Model
final class WorkSession {
    var taskLabel: String
    var durationSeconds: Int
    var completedAt: Date

    init(taskLabel: String, durationSeconds: Int, completedAt: Date = .now) {
        self.taskLabel = taskLabel
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
    }

    // Human-readable duration, e.g. "45 s", "25 min" or "1 h 5 min"
    var formattedDuration: String {
        if durationSeconds < 60 {
            return "\(durationSeconds) s"
        }
        let minutes = durationSeconds / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return remainingMinutes > 0 ? "\(hours) h \(remainingMinutes) min" : "\(hours) h"
        }
        return "\(minutes) min"
    }
}
