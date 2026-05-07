import Foundation
import SwiftData

@Model
final class DailyQuestClaim {
    @Attribute(.unique) var claimKey: String
    var questID: String
    var claimedAt: Date
    var xpAwarded: Int

    init(claimKey: String, questID: String, claimedAt: Date, xpAwarded: Int) {
        self.claimKey = claimKey
        self.questID = questID
        self.claimedAt = claimedAt
        self.xpAwarded = xpAwarded
    }
}

/// Singleton RPG progression row: allocatable stat points and three build axes.
@Model
final class PlayerStats {
    /// Fixed id so only one row is ever stored (`"main"`).
    @Attribute(.unique) var id: String

    /// Unspent points from boss clears and future rewards.
    var availableStatPoints: Int

    /// Reduces suggested rep targets for heavy compounds (UI layer applies this).
    var strengthStat: Int

    /// Percent bonus to accessory XP (1 point ≈ +1% in the gamification layer).
    var hypertrophyStat: Int

    /// Boosts passive XP on full rest days.
    var recoveryStat: Int
    /// Current progression XP pool.
    var totalXP: Int
    /// Local start-of-day stamp for last passive recovery award.
    var lastRecoveryXPAwardDay: Date?

    init(
        id: String = "main",
        availableStatPoints: Int = 0,
        strengthStat: Int = 0,
        hypertrophyStat: Int = 0,
        recoveryStat: Int = 0,
        totalXP: Int = 0,
        lastRecoveryXPAwardDay: Date? = nil
    ) {
        self.id = id
        self.availableStatPoints = availableStatPoints
        self.strengthStat = strengthStat
        self.hypertrophyStat = hypertrophyStat
        self.recoveryStat = recoveryStat
        self.totalXP = totalXP
        self.lastRecoveryXPAwardDay = lastRecoveryXPAwardDay
    }

    /// Ensures the single `PlayerStats` row exists after migrations or first launch.
    static func ensureExists(in context: ModelContext) {
        let descriptor = FetchDescriptor<PlayerStats>(
            predicate: #Predicate<PlayerStats> { stats in
                stats.id == "main"
            }
        )
        if let count = try? context.fetchCount(descriptor), count > 0 {
            return
        }
        context.insert(
            PlayerStats(
                id: "main",
                availableStatPoints: 0,
                strengthStat: 0,
                hypertrophyStat: 0,
                recoveryStat: 0,
                totalXP: 0,
                lastRecoveryXPAwardDay: nil
            )
        )
    }

    /// Awards boss-raid PR bonus points (call only when a new PR is confirmed).
    static func awardBossDefeatStatPoints(points: Int = 3, in context: ModelContext) {
        guard points > 0 else { return }
        ensureExists(in: context)
        let descriptor = FetchDescriptor<PlayerStats>(
            predicate: #Predicate<PlayerStats> { stats in
                stats.id == "main"
            }
        )
        guard let stats = try? context.fetch(descriptor).first else { return }
        stats.availableStatPoints += points
    }

    /// Accessory set XP (scaled by hypertrophy stat).
    static func accessoryXPForSet(reps: Int, hypertrophyStat: Int) -> Int {
        let base = max(1, reps / 2)
        let scaled = Double(base) * RPGProgressionEngine.hypertrophyXPMultiplier(stat: hypertrophyStat)
        return max(1, Int(scaled.rounded()))
    }

    static func awardAccessoryXP(reps: Int, in context: ModelContext) {
        ensureExists(in: context)
        let descriptor = FetchDescriptor<PlayerStats>(
            predicate: #Predicate<PlayerStats> { stats in
                stats.id == "main"
            }
        )
        guard let stats = try? context.fetch(descriptor).first else { return }
        stats.totalXP += accessoryXPForSet(reps: reps, hypertrophyStat: stats.hypertrophyStat)
    }

    static func rollbackAccessoryXP(reps: Int, in context: ModelContext) {
        ensureExists(in: context)
        let descriptor = FetchDescriptor<PlayerStats>(
            predicate: #Predicate<PlayerStats> { stats in
                stats.id == "main"
            }
        )
        guard let stats = try? context.fetch(descriptor).first else { return }
        let rollback = accessoryXPForSet(reps: reps, hypertrophyStat: stats.hypertrophyStat)
        stats.totalXP = max(0, stats.totalXP - rollback)
    }

    /// Awards passive XP once per rest day (no completed workout logged today).
    static func awardPassiveRecoveryXPIfEligible(
        allWorkoutDays: [WorkoutDay],
        now: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext
    ) -> Int {
        ensureExists(in: context)
        let descriptor = FetchDescriptor<PlayerStats>(
            predicate: #Predicate<PlayerStats> { stats in
                stats.id == "main"
            }
        )
        guard let stats = try? context.fetch(descriptor).first else { return 0 }

        let todayStart = calendar.startOfDay(for: now)
        if let last = stats.lastRecoveryXPAwardDay, calendar.isDate(last, inSameDayAs: todayStart) {
            return 0
        }

        let hasWorkoutToday = allWorkoutDays.contains { day in
            guard let completed = day.sessionCompletedAt else { return false }
            return calendar.isDate(completed, inSameDayAs: now)
        }
        guard !hasWorkoutToday else { return 0 }

        let award = RPGProgressionEngine.passiveRestDayXPBase(recoveryStat: stats.recoveryStat)
        stats.totalXP += award
        stats.lastRecoveryXPAwardDay = todayStart
        return award
    }

    /// Awards XP once per quest per calendar day.
    @discardableResult
    static func awardDailyQuestXPIfNeeded(
        questID: String,
        xp: Int,
        now: Date = .now,
        calendar: Calendar = .current,
        in context: ModelContext
    ) -> Bool {
        guard !questID.isEmpty, xp > 0 else { return false }
        ensureExists(in: context)

        let dayStart = calendar.startOfDay(for: now)
        let key = "\(questID)|\(Int(dayStart.timeIntervalSince1970))"

        let claimDescriptor = FetchDescriptor<DailyQuestClaim>(
            predicate: #Predicate<DailyQuestClaim> { claim in
                claim.claimKey == key
            }
        )
        if let already = try? context.fetchCount(claimDescriptor), already > 0 {
            return false
        }

        let statsDescriptor = FetchDescriptor<PlayerStats>(
            predicate: #Predicate<PlayerStats> { stats in
                stats.id == "main"
            }
        )
        guard let stats = try? context.fetch(statsDescriptor).first else { return false }

        stats.totalXP += xp
        context.insert(DailyQuestClaim(claimKey: key, questID: questID, claimedAt: now, xpAwarded: xp))
        return true
    }
}
