import Foundation
import SwiftData

enum PREngine {
    struct PRResult {
        let isNewRecord: Bool
        let previousMaxWeight: Double?
        let currentWeight: Double
        let currentReps: Int
    }

    /// PR chase state for an exercise on a scheduled day (within 5% of all-time max by recent loading).
    struct BossRaidStatus: Sendable {
        var isBossRaid: Bool
        /// All-time max weight from `PersonalRecord`, if any.
        var allTimeMaxWeight: Double?
        /// Best recent loading used for the comparison (completed history, else current template/working sets).
        var referenceLoad: Double?
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
        allTimeMaxWeight(for: exerciseName, in: context)
    }

    /// All-time max weight (`PersonalRecord`) for the exercise name.
    static func allTimeMaxWeight(for exerciseName: String, in context: ModelContext) -> Double? {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.exerciseName == trimmed }
        )
        return try? context.fetch(descriptor).first?.maxWeight
    }

    // MARK: - Boss raid (within 5% of all-time PR)

    /// Fraction of PR that counts as “on the boss” (e.g. 0.95 = last load ≥ 95% of all-time max).
    static var bossRaidLoadRatioThreshold: Double { 0.95 }

    /// True when recent loading for this lift is within 5% of the stored all-time max (from below or matching).
    static func isBossRaidExercise(
        exercise: Exercise,
        scheduledDay: WorkoutDay,
        in context: ModelContext
    ) -> Bool {
        bossRaidStatus(exercise: exercise, scheduledDay: scheduledDay, in: context).isBossRaid
    }

    /// Full boss evaluation for UI copy and debugging.
    static func bossRaidStatus(
        exercise: Exercise,
        scheduledDay: WorkoutDay,
        in context: ModelContext
    ) -> BossRaidStatus {
        guard exercise.kind == .strength else {
            return BossRaidStatus(isBossRaid: false, allTimeMaxWeight: nil, referenceLoad: nil)
        }

        let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return BossRaidStatus(isBossRaid: false, allTimeMaxWeight: nil, referenceLoad: nil)
        }

        guard let prMax = allTimeMaxWeight(for: name, in: context), prMax > 0 else {
            return BossRaidStatus(isBossRaid: false, allTimeMaxWeight: nil, referenceLoad: nil)
        }

        let reference = lastReferenceLoad(
            exerciseName: name,
            scheduledDay: scheduledDay,
            currentExercise: exercise,
            in: context
        )

        guard let load = reference, load > 0 else {
            return BossRaidStatus(isBossRaid: false, allTimeMaxWeight: prMax, referenceLoad: nil)
        }

        let ratio = load / prMax
        let isBoss = ratio >= bossRaidLoadRatioThreshold
        return BossRaidStatus(isBossRaid: isBoss, allTimeMaxWeight: prMax, referenceLoad: load)
    }

    /// Most recent “what you’ve been loading” for this lift: prior completed sessions first, else working weights on this exercise.
    private static func lastReferenceLoad(
        exerciseName: String,
        scheduledDay: WorkoutDay,
        currentExercise: Exercise,
        in context: ModelContext
    ) -> Double? {
        if let fromHistory = maxLoadFromCompletedHistory(
            exerciseName: exerciseName,
            excludingDay: scheduledDay,
            in: context
        ) {
            return fromHistory
        }
        return maxWorkingWeight(on: currentExercise)
    }

    private static func maxLoadFromCompletedHistory(
        exerciseName: String,
        excludingDay: WorkoutDay?,
        in context: ModelContext
    ) -> Double? {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<WorkoutDay>(
            predicate: #Predicate<WorkoutDay> { day in
                day.sessionCompletedAt != nil
            },
            sortBy: [SortDescriptor(\.sessionCompletedAt, order: .reverse)]
        )

        guard let days = try? context.fetch(descriptor) else { return nil }

        let excludeID = excludingDay?.persistentModelID
        for day in days {
            if let excludeID, day.persistentModelID == excludeID { continue }
            guard let match = day.exercises.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed
            }) else { continue }
            if let maxCompleted = maxCompletedSetWeight(on: match) {
                return maxCompleted
            }
        }
        return nil
    }

    private static func maxCompletedSetWeight(on exercise: Exercise) -> Double? {
        let weights = exercise.setLogs
            .filter { $0.isCompleted && $0.weight > 0 }
            .map { $0.weight }
        return weights.max()
    }

    /// Template / in-progress weights (any set with weight > 0) when there is no completed-session history.
    private static func maxWorkingWeight(on exercise: Exercise) -> Double? {
        let weights = exercise.setLogs.filter { $0.weight > 0 }.map { $0.weight }
        return weights.max()
    }
}
