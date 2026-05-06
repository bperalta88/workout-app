import Foundation

/// One-shot celebration after finishing a workout day (streak, totals, weekly goal, first workout).
struct MilestoneCelebration: Equatable {
    var title: String
    var subtitle: String
    var systemImage: String
}

enum MilestoneEvaluator {
    /// Call right after incrementing `completionCount` and setting `sessionCompletedAt` for the completed day.
    static func evaluateAfterDayComplete(
        allWorkoutDays: [WorkoutDay],
        weeklyWorkoutGoal: Int,
        calendar: Calendar = .current
    ) -> MilestoneCelebration? {
        let totalCompletions = allWorkoutDays.reduce(0) { $0 + $1.completionCount }

        if totalCompletions == 1 {
            return MilestoneCelebration(
                title: "First workout logged",
                subtitle: "You’re on the board. Keep showing up.",
                systemImage: "figure.strengthtraining.traditional"
            )
        }

        if let m = totalSessionsMilestone(totalCompletions: totalCompletions) {
            return m
        }

        if weeklyWorkoutGoal > 0 {
            let thisWeek = sessionsCompletedInCurrentWeek(allWorkoutDays: allWorkoutDays, calendar: calendar)
            if thisWeek == weeklyWorkoutGoal {
                return MilestoneCelebration(
                    title: "Weekly goal crushed",
                    subtitle: "You hit \(weeklyWorkoutGoal) workout\(weeklyWorkoutGoal == 1 ? "" : "s") this week.",
                    systemImage: "target"
                )
            }
        }

        let streak = calendarStreakDays(allWorkoutDays: allWorkoutDays, calendar: calendar)
        if streak >= 2 {
            return streakMilestone(streak: streak)
        }

        return nil
    }

    private static func totalSessionsMilestone(totalCompletions: Int) -> MilestoneCelebration? {
        let tiers = [5, 10, 25, 50, 100]
        guard tiers.contains(totalCompletions) else { return nil }
        return MilestoneCelebration(
            title: "\(totalCompletions) workouts",
            subtitle: "That’s real consistency. Nice work.",
            systemImage: "flame.fill"
        )
    }

    private static func streakMilestone(streak: Int) -> MilestoneCelebration {
        let title: String
        let subtitle: String
        switch streak {
        case 2:
            title = "2 days in a row"
            subtitle = "Momentum is building."
        case 3:
            title = "3-day streak"
            subtitle = "Habit mode: on."
        case 7:
            title = "7-day streak"
            subtitle = "A full week of training days."
        case 14:
            title = "14-day streak"
            subtitle = "Two weeks straight. Rare air."
        case 30:
            title = "30-day streak"
            subtitle = "That’s a serious run."
        default:
            title = "\(streak)-day streak"
            subtitle = "Keep stacking those training days."
        }
        return MilestoneCelebration(
            title: title,
            subtitle: subtitle,
            systemImage: "calendar.badge.checkmark"
        )
    }

    /// Calendar days (local) with at least one program day marked complete, ending today.
    private static func calendarStreakDays(allWorkoutDays: [WorkoutDay], calendar: Calendar) -> Int {
        var trainedDays = Set<Date>()
        for day in allWorkoutDays {
            guard let t = day.sessionCompletedAt else { continue }
            trainedDays.insert(calendar.startOfDay(for: t))
        }
        let today = calendar.startOfDay(for: Date())
        guard trainedDays.contains(today) else { return 0 }
        var streak = 0
        var d = today
        while trainedDays.contains(d) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: d) else { break }
            d = prev
        }
        return streak
    }

    private static func sessionsCompletedInCurrentWeek(allWorkoutDays: [WorkoutDay], calendar: Calendar) -> Int {
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return 0 }
        return allWorkoutDays.filter { day in
            guard let t = day.sessionCompletedAt else { return false }
            return t >= weekStart && t < weekEnd
        }.count
    }
}
