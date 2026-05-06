import Foundation
import SwiftData

@Model
final class WorkoutDay {
    var dayIndex: Int
    var focus: String
    var sessionStartedAt: Date?
    var sessionCompletedAt: Date?
    var isSessionActive: Bool
    var completionCount: Int

    @Relationship(deleteRule: .cascade, inverse: \Exercise.workoutDay)
    var exercises: [Exercise]

    var program: WorkoutProgram?

    init(
        dayIndex: Int,
        focus: String,
        sessionStartedAt: Date? = nil,
        sessionCompletedAt: Date? = nil,
        isSessionActive: Bool = false,
        completionCount: Int = 0,
        exercises: [Exercise] = []
    ) {
        self.dayIndex = dayIndex
        self.focus = focus
        self.sessionStartedAt = sessionStartedAt
        self.sessionCompletedAt = sessionCompletedAt
        self.isSessionActive = isSessionActive
        self.completionCount = completionCount
        self.exercises = exercises
    }

    var sortedExercises: [Exercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }
}
