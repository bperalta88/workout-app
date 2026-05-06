import Foundation
import SwiftData

/// The active training plan (seeded program). Imported archives use other program names.
enum PrimaryProgram {
    static var name: String { WorkoutProgramSeed.programName }

    static func isPrimary(_ day: WorkoutDay) -> Bool {
        day.program?.name == name
    }

    static func daysSorted(from allDays: [WorkoutDay]) -> [WorkoutDay] {
        allDays
            .filter { isPrimary($0) }
            .sorted { $0.dayIndex < $1.dayIndex }
    }

    /// Maps a calendar date to program Day 1…7. `weekStartsOnWeekday` is `Calendar` weekday (1 = Sunday … 7 = Saturday). Default **2 = Monday** means Mon → Day 1.
    static func programDayIndex(for date: Date = Date(), weekStartsOnWeekday: Int) -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - weekStartsOnWeekday + 7) % 7 + 1
    }
}
