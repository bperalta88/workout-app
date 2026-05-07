import Foundation

/// Centralized RPG scaling helpers (stats → gameplay effects).
enum RPGProgressionEngine {
    enum FormStage: Int, CaseIterable {
        case kidGohan
        case superSaiyanGohan
        case teenSuperSaiyan2
        case ultimateGohan
        case mysticAwakened
        case beastGohan
    }

    /// Every 5 Strength points trims 1 rep from heavy barbell targets.
    static func adjustedRepTargetText(base text: String, strengthStat: Int, applies: Bool) -> String {
        guard applies, strengthStat > 0 else { return text }
        guard let regex = try? NSRegularExpression(pattern: #"(\d+)\s*[-–]\s*(\d+)"#) else { return text }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let lowRange = Range(match.range(at: 1), in: text),
              let highRange = Range(match.range(at: 2), in: text),
              let low = Int(text[lowRange]),
              let high = Int(text[highRange]) else {
            return text
        }

        let repReduction = max(0, strengthStat / 5)
        let newLow = max(3, low - repReduction)
        let newHigh = max(newLow, high - repReduction)
        let replacement = "\(newLow)-\(newHigh)"
        let full = Range(match.range(at: 0), in: text) ?? lowRange
        return text.replacingCharacters(in: full, with: replacement)
    }

    static func hypertrophyXPMultiplier(stat: Int) -> Double {
        1 + (Double(max(0, stat)) * 0.01)
    }

    static func passiveRestDayXPBase(recoveryStat: Int) -> Int {
        10 + max(0, recoveryStat)
    }

    static func isHeavyBarbellCompound(exerciseName: String) -> Bool {
        let n = exerciseName.lowercased()
        let heavyKeywords = [
            "barbell bench", "bench press", "squat", "deadlift", "dead lift",
            "barbell row", "bent over row", "overhead press", "military press", "front squat"
        ]
        return heavyKeywords.contains { n.contains($0) }
    }

    static func isAccessoryMovement(exerciseName: String) -> Bool {
        !isHeavyBarbellCompound(exerciseName: exerciseName)
    }

    // MARK: - Leveling / class fantasy

    /// Quadratic-ish progression that feels faster early, slower later.
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let l = max(1, level - 1)
        return (l * l * 38) + (l * 62)
    }

    static func level(forXP xp: Int) -> Int {
        let clamped = max(0, xp)
        var level = 1
        while xpRequired(forLevel: level + 1) <= clamped {
            level += 1
            if level > 250 { break }
        }
        return level
    }

    static func xpIntoCurrentLevel(xp: Int) -> Int {
        let lvl = level(forXP: xp)
        return max(0, xp - xpRequired(forLevel: lvl))
    }

    static func xpNeededForNextLevel(xp: Int) -> Int {
        let lvl = level(forXP: xp)
        let currentFloor = xpRequired(forLevel: lvl)
        let next = xpRequired(forLevel: lvl + 1)
        return max(1, next - currentFloor)
    }

    static func formStage(forLevel level: Int) -> FormStage {
        switch level {
        case ..<8: return .kidGohan
        case ..<14: return .superSaiyanGohan
        case ..<22: return .teenSuperSaiyan2
        case ..<34: return .ultimateGohan
        case ..<50: return .mysticAwakened
        default: return .beastGohan
        }
    }

    static func classTitle(for stats: PlayerStats) -> String {
        let sorted = [
            ("Vanguard", stats.strengthStat),
            ("Arcanist", stats.hypertrophyStat),
            ("Warden", stats.recoveryStat)
        ].sorted { $0.1 > $1.1 }

        if sorted[0].1 == sorted[1].1, sorted[1].1 == sorted[2].1 {
            return "Balanced Sentinel"
        }
        if sorted[0].1 == sorted[1].1 {
            return "\(sorted[0].0)-\(sorted[1].0) Hybrid"
        }
        return "\(sorted[0].0) Specialist"
    }
}
