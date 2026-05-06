import Foundation
import SwiftData

@Model
final class WorkoutDay {
    var dayIndex: Int
    var focus: String

    @Relationship(deleteRule: .cascade, inverse: \Exercise.workoutDay)
    var exercises: [Exercise]

    var program: WorkoutProgram?

    init(dayIndex: Int, focus: String, exercises: [Exercise] = []) {
        self.dayIndex = dayIndex
        self.focus = focus
        self.exercises = exercises
    }

    var sortedExercises: [Exercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }
}
