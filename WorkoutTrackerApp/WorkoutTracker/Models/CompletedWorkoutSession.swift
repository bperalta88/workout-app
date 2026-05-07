import Foundation
import SwiftData

/// Immutable snapshot created when a workout day is completed.
@Model
final class CompletedWorkoutSession {
    var sourceDayIndex: Int
    var dayFocus: String
    var completedAt: Date
    var completionCountAtCapture: Int

    @Relationship(deleteRule: .cascade, inverse: \CompletedExerciseSnapshot.session)
    var exerciseSnapshots: [CompletedExerciseSnapshot]

    init(
        sourceDayIndex: Int,
        dayFocus: String,
        completedAt: Date = .now,
        completionCountAtCapture: Int,
        exerciseSnapshots: [CompletedExerciseSnapshot] = []
    ) {
        self.sourceDayIndex = sourceDayIndex
        self.dayFocus = dayFocus
        self.completedAt = completedAt
        self.completionCountAtCapture = completionCountAtCapture
        self.exerciseSnapshots = exerciseSnapshots
    }
}

@Model
final class CompletedExerciseSnapshot {
    var name: String
    var targetSetsReps: String
    var kindRaw: String
    var cardioCompleted: Bool
    var cardioDurationNote: String
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \CompletedSetSnapshot.exercise)
    var setSnapshots: [CompletedSetSnapshot]

    var session: CompletedWorkoutSession?

    init(
        name: String,
        targetSetsReps: String,
        kindRaw: String,
        cardioCompleted: Bool,
        cardioDurationNote: String,
        sortOrder: Int,
        setSnapshots: [CompletedSetSnapshot] = []
    ) {
        self.name = name
        self.targetSetsReps = targetSetsReps
        self.kindRaw = kindRaw
        self.cardioCompleted = cardioCompleted
        self.cardioDurationNote = cardioDurationNote
        self.sortOrder = sortOrder
        self.setSnapshots = setSnapshots
    }

    var kind: ExerciseKind {
        ExerciseKind(rawValue: kindRaw) ?? .strength
    }
}

@Model
final class CompletedSetSnapshot {
    var setIndex: Int
    var reps: Int
    var weight: Double
    var isCompleted: Bool

    var exercise: CompletedExerciseSnapshot?

    init(setIndex: Int, reps: Int, weight: Double, isCompleted: Bool) {
        self.setIndex = setIndex
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
    }
}
