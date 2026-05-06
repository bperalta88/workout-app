import Foundation
import SwiftData

/// Seeds the 6-day program shell plus **exact** Day 1 & Day 2 exercises from the Google Sheet.
enum WorkoutProgramSeed {
    static let programName = "Workout Plan"

    /// Call once (e.g. on first launch) when the store has no `WorkoutProgram`.
    @MainActor
    static func insertDefaultProgramIfNeeded(in context: ModelContext) {
        var fetch = FetchDescriptor<WorkoutProgram>()
        fetch.fetchLimit = 1
        if let count = try? context.fetchCount(fetch), count > 0 {
            return
        }

        let program = WorkoutProgram(name: programName)
        program.days = [
            makeDay1(),
            makeDay2(),
            makeDay3(),
            makeDay4(),
            makeDay5(),
            makeDay6(),
        ]
        program.days.forEach { $0.program = program }
        context.insert(program)
    }

    // MARK: - Day 1 · Chest & Tri (sheet values)

    private static func makeDay1() -> WorkoutDay {
        let day = WorkoutDay(dayIndex: 1, focus: "Chest & Tri")
        day.exercises = [
            Exercise(
                name: "Barbell bench press",
                targetSetsReps: "4 x 8-10",
                kind: .strength,
                sortOrder: 0,
                setLogs: [
                    SetLog(setIndex: 1, reps: 10, weight: 70),
                    SetLog(setIndex: 2, reps: 8, weight: 95),
                    SetLog(setIndex: 3, reps: 6, weight: 105),
                    SetLog(setIndex: 4, reps: 8, weight: 110),
                ]
            ),
            Exercise(
                name: "Incline dumbbell",
                targetSetsReps: "4 x 10-12",
                kind: .strength,
                sortOrder: 1,
                setLogs: [
                    SetLog(setIndex: 1, reps: 10, weight: 45),
                    SetLog(setIndex: 2, reps: 10, weight: 47.5),
                    SetLog(setIndex: 3, reps: 10, weight: 52.5),
                    SetLog(setIndex: 4, reps: 10, weight: 50),
                ]
            ),
            Exercise(
                name: "Cable Chest fly",
                targetSetsReps: "3 x 12-15",
                kind: .strength,
                sortOrder: 2,
                setLogs: [
                    SetLog(setIndex: 1, reps: 12, weight: 19),
                    SetLog(setIndex: 2, reps: 12, weight: 21.5),
                    SetLog(setIndex: 3, reps: 15, weight: 21.5),
                ]
            ),
            Exercise(
                name: "Tricep Pushdown",
                targetSetsReps: "3 x 10-12",
                kind: .strength,
                sortOrder: 3,
                setLogs: [
                    SetLog(setIndex: 1, reps: 12, weight: 32.5),
                    SetLog(setIndex: 2, reps: 10, weight: 32.5),
                    SetLog(setIndex: 3, reps: 10, weight: 32.5),
                ]
            ),
            Exercise(
                name: "Overhead Tricep",
                targetSetsReps: "3 x 12",
                kind: .strength,
                sortOrder: 4,
                setLogs: [
                    SetLog(setIndex: 1, reps: 12, weight: 30),
                    SetLog(setIndex: 2, reps: 12, weight: 30),
                    SetLog(setIndex: 3, reps: 12, weight: 30),
                ]
            ),
            Exercise(
                name: "Cardio",
                targetSetsReps: "20 min",
                kind: .cardio,
                sortOrder: 5,
                cardioCompleted: false,
                cardioDurationNote: "20 Min Incline Walk"
            ),
        ]
        attachParent(day)
        return day
    }

    // MARK: - Day 2 · Back & Bi

    private static func makeDay2() -> WorkoutDay {
        let day = WorkoutDay(dayIndex: 2, focus: "Back & Bi")
        day.exercises = [
            Exercise(
                name: "Barbell Row",
                targetSetsReps: "4 x 8-10",
                kind: .strength,
                sortOrder: 0,
                setLogs: [
                    SetLog(setIndex: 1, reps: 10, weight: 20),
                    SetLog(setIndex: 2, reps: 10, weight: 30),
                    SetLog(setIndex: 3, reps: 8, weight: 40),
                    SetLog(setIndex: 4, reps: 8, weight: 50),
                ]
            ),
            Exercise(
                name: "Lat Pulldown",
                targetSetsReps: "4 x 8-10",
                kind: .strength,
                sortOrder: 1,
                setLogs: [
                    SetLog(setIndex: 1, reps: 10, weight: 70),
                    SetLog(setIndex: 2, reps: 10, weight: 85),
                    SetLog(setIndex: 3, reps: 10, weight: 90),
                    SetLog(setIndex: 4, reps: 10, weight: 90),
                ]
            ),
            Exercise(
                name: "Seated Cable Row",
                targetSetsReps: "3 x 10-12",
                kind: .strength,
                sortOrder: 2,
                setLogs: [
                    SetLog(setIndex: 1, reps: 12, weight: 35),
                    SetLog(setIndex: 2, reps: 12, weight: 42.5),
                    SetLog(setIndex: 3, reps: 12, weight: 42.5),
                ]
            ),
            Exercise(
                name: "Barbell bicep curl",
                targetSetsReps: "3 x 10",
                kind: .strength,
                sortOrder: 3,
                setLogs: [
                    SetLog(setIndex: 1, reps: 10, weight: 50),
                    SetLog(setIndex: 2, reps: 10, weight: 50),
                    SetLog(setIndex: 3, reps: 10, weight: 50),
                ]
            ),
            Exercise(
                name: "Hammer Curl",
                targetSetsReps: "3 x 10",
                kind: .strength,
                sortOrder: 4,
                setLogs: [
                    SetLog(setIndex: 1, reps: 10, weight: 27.5),
                    SetLog(setIndex: 2, reps: 10, weight: 27.5),
                    SetLog(setIndex: 3, reps: 10, weight: 30),
                ]
            ),
            Exercise(
                name: "Cardio",
                targetSetsReps: "20 min",
                kind: .cardio,
                sortOrder: 5,
                cardioCompleted: false,
                cardioDurationNote: "20 Min Incline Walk"
            ),
        ]
        attachParent(day)
        return day
    }

    // MARK: - Placeholder days 3–6 (structure only)

    private static func makeDay3() -> WorkoutDay {
        let day = WorkoutDay(dayIndex: 3, focus: "Lower Body")
        day.exercises = [
            placeholderStrength("Hack squat", "4 x 8-10", 4, 0),
            placeholderStrength("Leg Press", "4 x 10-12", 4, 1),
            placeholderStrength("Leg curl machine", "3 x 12-15", 3, 2),
            placeholderStrength("Leg extension", "3 x 12-15", 3, 3),
            placeholderStrength("Standing Calf Raise", "4 x 12-15", 4, 4),
            cardioBlock(sortOrder: 5),
        ]
        attachParent(day)
        return day
    }

    private static func makeDay4() -> WorkoutDay {
        let day = WorkoutDay(dayIndex: 4, focus: "Shoulders & Abs")
        day.exercises = [
            placeholderStrength("Dumbbell Shoulder Press", "4 x 8-10", 4, 0),
            placeholderStrength("Lateral Raises", "3 x 12-15", 3, 1),
            placeholderStrength("Rear Delt Fly", "3 x 12-15", 3, 2),
            placeholderStrength("Cable Crunch", "3 x 12-15", 3, 3),
            placeholderStrength("Hanging Leg Raise", "3 x 10-12", 3, 4),
            cardioBlock(sortOrder: 5),
        ]
        attachParent(day)
        return day
    }

    private static func makeDay5() -> WorkoutDay {
        let day = WorkoutDay(dayIndex: 5, focus: "Upper Strength")
        day.exercises = [
            placeholderStrength("Incline Bench Press", "4 x 6-8", 4, 0),
            placeholderStrength("Pull Ups (or Assisted)", "4 x AMRAP", 4, 1),
            placeholderStrength("Chest Supported Row", "4 x 8-10", 4, 2),
            placeholderStrength("EZ Bar Curl", "3 x 10", 3, 3),
            placeholderStrength("Tricep Dips", "3 x 10-12", 3, 4),
            cardioBlock(sortOrder: 5),
        ]
        attachParent(day)
        return day
    }

    private static func makeDay6() -> WorkoutDay {
        let day = WorkoutDay(dayIndex: 6, focus: "OPTIONAL")
        day.exercises = [
            Exercise(
                name: "Walking",
                targetSetsReps: "45–60 min",
                kind: .cardio,
                sortOrder: 0,
                cardioCompleted: false,
                cardioDurationNote: "45 to 60 minutes walking"
            ),
            Exercise(
                name: "Planks",
                targetSetsReps: "3 x 60s",
                kind: .strength,
                sortOrder: 1,
                setLogs: [
                    SetLog(setIndex: 1, reps: 60, weight: 0),
                    SetLog(setIndex: 2, reps: 60, weight: 0),
                    SetLog(setIndex: 3, reps: 60, weight: 0),
                ]
            ),
        ]
        attachParent(day)
        return day
    }

    // MARK: - Helpers

    private static func attachParent(_ day: WorkoutDay) {
        for ex in day.exercises {
            ex.workoutDay = day
            for s in ex.setLogs {
                s.exercise = ex
            }
        }
    }

    private static func placeholderStrength(
        _ name: String,
        _ target: String,
        _ sets: Int,
        _ sortOrder: Int
    ) -> Exercise {
        var logs: [SetLog] = []
        for i in 1...sets {
            logs.append(SetLog(setIndex: i, reps: 0, weight: 0))
        }
        return Exercise(
            name: name,
            targetSetsReps: target,
            kind: .strength,
            sortOrder: sortOrder,
            setLogs: logs
        )
    }

    private static func cardioBlock(sortOrder: Int) -> Exercise {
        Exercise(
            name: "Cardio",
            targetSetsReps: "20 min",
            kind: .cardio,
            sortOrder: sortOrder,
            cardioCompleted: false,
            cardioDurationNote: "20 Min Incline Walk"
        )
    }
}
