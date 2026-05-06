import Foundation
import SwiftData

enum PREngine {
    struct PRResult {
        let isNewRecord: Bool
        let previousMaxWeight: Double?
        let currentWeight: Double
        let currentReps: Int
    }

    /// Returns detailed record evaluation so the UI can render richer celebration states.
    static func evaluateCompletionForPersonalRecord(
        exerciseName: String,
        weight: Double,
        reps: Int,
        in context: ModelContext
    ) -> PRResult {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, weight > 0 else {
            return PRResult(
                isNewRecord: false,
                previousMaxWeight: nil,
                currentWeight: weight,
                currentReps: reps
            )
        }

        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == trimmed }
        )

        if let existing = try? context.fetch(descriptor).first {
            let previous = existing.maxWeight
            if weight > existing.maxWeight {
                existing.maxWeight = weight
                existing.repsAtMaxWeight = reps
                existing.achievedAt = .now
                return PRResult(
                    isNewRecord: true,
                    previousMaxWeight: previous,
                    currentWeight: weight,
                    currentReps: reps
                )
            }
            return PRResult(
                isNewRecord: false,
                previousMaxWeight: previous,
                currentWeight: weight,
                currentReps: reps
            )
        }

        context.insert(
            PersonalRecord(
                exerciseName: trimmed,
                maxWeight: weight,
                repsAtMaxWeight: reps,
                achievedAt: .now
            )
        )
        return PRResult(
            isNewRecord: true,
            previousMaxWeight: nil,
            currentWeight: weight,
            currentReps: reps
        )
    }

    /// Returns `true` if this completion is a new all-time max weight for `exerciseName`.
    @discardableResult
    static func registerCompletionIfPersonalRecord(
        exerciseName: String,
        weight: Double,
        reps: Int,
        in context: ModelContext
    ) -> Bool {
        evaluateCompletionForPersonalRecord(
            exerciseName: exerciseName,
            weight: weight,
            reps: reps,
            in: context
        ).isNewRecord
    }

    static func currentMaxWeight(for exerciseName: String, in context: ModelContext) -> Double? {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == trimmed }
        )
        return try? context.fetch(descriptor).first?.maxWeight
    }
}
