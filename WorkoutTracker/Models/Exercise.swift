import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    /// Reference goal from program sheet, e.g. "4 x 8-10"
    var targetSetsReps: String
    /// `ExerciseKind.rawValue`
    var kindRaw: String
    var sortOrder: Int

    // Cardio-only
    var cardioCompleted: Bool
    var cardioDurationNote: String

    @Relationship(deleteRule: .cascade, inverse: \SetLog.exercise)
    var setLogs: [SetLog]

    var workoutDay: WorkoutDay?

    init(
        name: String,
        targetSetsReps: String,
        kind: ExerciseKind = .strength,
        sortOrder: Int = 0,
        cardioCompleted: Bool = false,
        cardioDurationNote: String = "",
        setLogs: [SetLog] = []
    ) {
        self.name = name
        self.targetSetsReps = targetSetsReps
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.cardioCompleted = cardioCompleted
        self.cardioDurationNote = cardioDurationNote
        self.setLogs = setLogs
    }

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    var sortedSetLogs: [SetLog] {
        setLogs.sorted { $0.setIndex < $1.setIndex }
    }
}
