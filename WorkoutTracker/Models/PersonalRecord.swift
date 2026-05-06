import Foundation
import SwiftData

/// One row per exercise name — tracks all-time max weight for that lift.
@Model
final class PersonalRecord {
    @Attribute(.unique) var exerciseName: String
    var maxWeight: Double
    var repsAtMaxWeight: Int
    var achievedAt: Date

    init(
        exerciseName: String,
        maxWeight: Double,
        repsAtMaxWeight: Int,
        achievedAt: Date = .now
    ) {
        self.exerciseName = exerciseName
        self.maxWeight = maxWeight
        self.repsAtMaxWeight = repsAtMaxWeight
        self.achievedAt = achievedAt
    }
}
