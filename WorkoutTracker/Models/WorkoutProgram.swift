import Foundation
import SwiftData

@Model
final class WorkoutProgram {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.program)
    var days: [WorkoutDay]

    init(name: String, createdAt: Date = .now, days: [WorkoutDay] = []) {
        self.name = name
        self.createdAt = createdAt
        self.days = days
    }
}
