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

    /// Shows current set count in the program target string, e.g. "4 x 12" → "3 x 12" after deleting a set.
    var displayTargetSetsReps: String {
        guard kind == .strength, !setLogs.isEmpty else { return targetSetsReps }
        let count = setLogs.count
        let template = targetSetsReps
        guard let regex = try? NSRegularExpression(pattern: #"^\s*(\d+)(\s*[x×]\s*)"#, options: .caseInsensitive) else {
            return "\(count) sets · \(template)"
        }
        let range = NSRange(template.startIndex..., in: template)
        guard let match = regex.firstMatch(in: template, options: [], range: range),
              let numRange = Range(match.range(at: 1), in: template) else {
            return "\(count) sets · \(template)"
        }
        return template.replacingCharacters(in: numRange, with: "\(count)")
    }

    /// Heuristic for showing barbell plate math (excludes DB, cables, machines, KB).
    var suggestsPlateLoading: Bool {
        guard kind == .strength else { return false }
        let n = name.lowercased()
        let exclude = ["dumbbell", "dumbell", "cable", "machine", "kettlebell", "kb ", " trx"]
        if exclude.contains(where: { n.contains($0) }) { return false }
        if n.contains("barbell") || n.contains("bb bench") || n.contains("bb row") { return true }
        let hints = [
            "bench", "squat", "deadlift", "dead lift", "rdl", "romanian", "thrust", "row", "press",
            "curl", "lunge", "raise", "clean", "snatch"
        ]
        return hints.contains { n.contains($0) }
    }
}
