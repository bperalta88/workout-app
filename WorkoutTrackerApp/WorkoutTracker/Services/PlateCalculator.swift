import Foundation

/// US-style Olympic plate breakdown (per side) for a barbell total that includes the bar.
enum PlateCalculator {
    /// Default Olympic bar weight (lb) for total-on-bar calculations.
    static let defaultBarWeightLb: Double = 45

    /// Standard full-size plates descending (pounds).
    static let standardPlatesLb: [Double] = [45, 35, 25, 10, 5, 2.5]

    /// Converts a displayed weight to pounds for plate math when the user logs in kg.
    static func weightInPounds(displayValue: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .lb: return displayValue
        case .kg: return displayValue * 2.2046226218
        }
    }

    /// Ordered list of `(plateLb, countPerSide)` greedy from largest plate.
    static func platesPerSide(
        totalWeightLb: Double,
        barWeightLb: Double = defaultBarWeightLb
    ) -> [(plate: Double, count: Int)] {
        let perSide = (totalWeightLb - barWeightLb) / 2
        guard perSide > 0.01 else { return [] }

        var remaining = (perSide * 4).rounded(.down) / 4
        var result: [(Double, Int)] = []

        for plate in standardPlatesLb {
            guard plate > 0 else { continue }
            let n = Int((remaining / plate).rounded(.down))
            if n > 0 {
                result.append((plate, n))
                remaining -= Double(n) * plate
            }
        }

        return result
    }

    /// Dictionary form: plate weight → count per side.
    static func platesPerSideDict(totalWeightLb: Double, barWeightLb: Double = defaultBarWeightLb) -> [Double: Int] {
        Dictionary(uniqueKeysWithValues: platesPerSide(totalWeightLb: totalWeightLb, barWeightLb: barWeightLb).map { ($0.plate, $0.count) })
    }
}
