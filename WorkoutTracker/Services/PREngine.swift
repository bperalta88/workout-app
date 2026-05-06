import Foundation
import SwiftData

enum PREngine {
    /// Returns `true` if this completion is a new all-time max weight for `exerciseName`.
    @discardableResult
    static func registerCompletionIfPersonalRecord(
        exerciseName: String,
        weight: Double,
        reps: Int,
        in context: ModelContext
    ) -> Bool {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, weight > 0 else { return false }

        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == trimmed }
        )

        if let existing = try? context.fetch(descriptor).first {
            if weight > existing.maxWeight {
                existing.maxWeight = weight
                existing.repsAtMaxWeight = reps
                existing.achievedAt = .now
                return true
            }
            return false
        }

        context.insert(
            PersonalRecord(
                exerciseName: trimmed,
                maxWeight: weight,
                repsAtMaxWeight: reps,
                achievedAt: .now
            )
        )
        return true
    }

    static func currentMaxWeight(for exerciseName: String, in context: ModelContext) -> Double? {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == trimmed }
        )
        return try? context.fetch(descriptor).first?.maxWeight
    }
}
