import SwiftUI

/// Sheet + bar graphic for per-side plate loading (45 lb bar, standard US plates).
struct PlateLoadingSheet: View {
    var totalDisplay: Double
    var unit: WeightUnit

    @Environment(\.dismiss) private var dismiss

    private var totalLb: Double {
        PlateCalculator.weightInPounds(displayValue: totalDisplay, unit: unit)
    }

    private var breakdown: [(plate: Double, count: Int)] {
        PlateCalculator.platesPerSide(totalWeightLb: totalLb)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if totalDisplay <= 0 {
                        Text("Enter the total weight on the bar (including the bar) in the set row, then open Plate helper again.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.bodyText)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Per side")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedText)
                            Text(summaryLine)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppTheme.titleText)
                        }

                        Text("Assumes a 45 lb bar and full-size plates (45, 35, 25, 10, 5, 2.5 lb). Mirror the same stack on the other sleeve.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedText)

                        PlateBarDiagram(platesPerSide: breakdown)
                            .frame(maxWidth: .infinity)

                        if let residual = residualMessage {
                            Text(residual)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Plate helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var summaryLine: String {
        if breakdown.isEmpty {
            return totalLb <= 45
                ? "Nothing to add—total is at or below a 45 lb bar."
                : "Could not match standard plates exactly for \(Int(totalLb)) lb total."
        }
        let parts = breakdown.map { "\($0.count)×\($0.plate == floor($0.plate) ? String(format: "%.0f", $0.plate) : String(format: "%.1f", $0.plate)) lb" }
        return parts.joined(separator: " + ")
    }

    private var residualMessage: String? {
        let bar = PlateCalculator.defaultBarWeightLb
        let targetPerSide = (totalLb - bar) / 2
        guard targetPerSide > 0.01 else { return nil }
        let used = breakdown.reduce(0.0) { $0 + $1.plate * Double($1.count) }
        let delta = targetPerSide - used
        if delta > 0.25 {
            return String(format: "About %.1f lb per side isn’t covered by standard plates—use a pair of change plates or micro-load.", delta)
        }
        return nil
    }
}

private struct PlateBarDiagram: View {
    var platesPerSide: [(plate: Double, count: Int)]

    private var expandedOneSide: [Double] {
        platesPerSide.flatMap { pair in Array(repeating: pair.plate, count: pair.count) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(expandedOneSide.enumerated()), id: \.offset) { _, lb in
                        PlateDiscColumn(weightLb: lb)
                    }
                    BarSleeveColumn()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
            }
            .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct PlateDiscColumn: View {
    var weightLb: Double

    private var height: CGFloat {
        let base: CGFloat = 26
        let extra = CGFloat(weightLb / 45) * 38
        return min(72, base + extra)
    }

    private var width: CGFloat {
        switch weightLb {
        case 45: return 14
        case 35: return 13
        case 25: return 12
        case 10: return 10
        case 5: return 9
        default: return 8
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.45), Color(white: 0.22)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                )
        }
    }

    private var label: String {
        if weightLb == floor(weightLb) { return String(format: "%.0f", weightLb) }
        return String(format: "%.1f", weightLb)
    }
}

private struct BarSleeveColumn: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("bar")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.mutedText)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.55, blue: 0.58),
                            Color(red: 0.32, green: 0.32, blue: 0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 18, height: 78)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        }
    }
}
