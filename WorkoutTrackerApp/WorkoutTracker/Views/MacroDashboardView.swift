import SwiftUI
import SwiftData

/// Home hero: today’s macros from `MealLog`, calendar day only (local midnight → midnight).
struct MacroDashboardView: View {
    var onTapNutrition: () -> Void

    @Query(sort: \MealLog.loggedAt, order: .reverse) private var mealLogs: [MealLog]

    @AppStorage("nutritionDailyProteinGoal") private var proteinGoal = 170
    @AppStorage("nutritionDailyCarbsGoal") private var carbsGoal = 220
    @AppStorage("nutritionDailyFatGoal") private var fatGoal = 70
    @AppStorage("nutritionDailyCalorieGoal") private var calorieGoal = 2200

    private var calendar: Calendar { Calendar.current }

    /// `[startOfToday, startOfTomorrow)` — strict calendar-day window.
    private var todaysMeals: [MealLog] {
        let now = Date()
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return mealLogs.filter { $0.loggedAt >= start && $0.loggedAt < end }
    }

    private var totals: (cal: Double, p: Double, c: Double, f: Double) {
        todaysMeals.reduce(into: (0, 0, 0, 0)) { acc, m in
            acc.0 += m.calories
            acc.1 += m.proteinG
            acc.2 += m.carbsG
            acc.3 += m.fatG
        }
    }

    var body: some View {
        let t = totals
        let pg = max(1, proteinGoal)
        let cg = max(1, carbsGoal)
        let fg = max(1, fatGoal)
        let kcalGoal = max(1, calorieGoal)

        let pProgress = min(1.15, t.p / Double(pg))
        let carbsProgress = min(1.15, t.c / Double(cg))
        let fatProgress = min(1.15, t.f / Double(fg))
        let calProgress = min(1.15, t.cal / Double(kcalGoal))

        Button(action: onTapNutrition) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Today’s fuel", systemImage: "leaf.circle.fill")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.titleText)
                    Spacer()
                    Text(Date.now.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText.opacity(0.8))
                }

                HStack(alignment: .center, spacing: 14) {
                    proteinHeroRing(current: t.p, goal: Double(pg), progress: pProgress)

                    VStack(spacing: 10) {
                        secondaryMetricRing(
                            title: "Carbs",
                            value: t.c,
                            goal: Double(cg),
                            progress: carbsProgress,
                            unit: "g",
                            color: .orange
                        )
                        secondaryMetricRing(
                            title: "Fat",
                            value: t.f,
                            goal: Double(fg),
                            progress: fatProgress,
                            unit: "g",
                            color: .pink
                        )
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 10) {
                    caloriesBento(current: t.cal, goal: Double(kcalGoal), progress: calProgress)
                    remainingHint(protein: t.p, goalP: Double(pg), calories: t.cal, goalCal: Double(kcalGoal))
                }
            }
            .padding(16)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        }
        .buttonStyle(.plain)
    }

    private func proteinHeroRing(current: Double, goal: Double, progress: Double) -> some View {
        let size: CGFloat = 148
        let lineWidth: CGFloat = 14

        return ZStack {
            Circle()
                .stroke(AppTheme.subtleFill, lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: min(1, progress))
                .stroke(
                    AngularGradient(
                        colors: [AppTheme.accentLime, Color(red: 0.4, green: 0.85, blue: 0.45)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)

            VStack(spacing: 4) {
                Text("\(Int(current.rounded()))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.titleText)
                    .minimumScaleFactor(0.8)
                Text("protein / \(Int(goal)) g")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Protein \(Int(current)) of \(Int(goal)) grams")
    }

    private func secondaryMetricRing(title: String, value: Double, goal: Double, progress: Double, unit: String, color: Color) -> some View {
        let size: CGFloat = 56
        let lw: CGFloat = 6

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(AppTheme.subtleFill, lineWidth: lw)
                    .frame(width: size, height: size)
                Circle()
                    .trim(from: 0, to: min(1, progress))
                    .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption2, design: .default, weight: .bold))
                    .foregroundStyle(AppTheme.mutedText)
                Text("\(Int(value.rounded())) / \(Int(goal)) \(unit)")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppTheme.subtleFill.opacity(AppTheme.isDarkModeEnabled ? 0.5 : 0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(Int(value)) of \(Int(goal)) \(unit)")
    }

    private func caloriesBento(current: Double, goal: Double, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryBlue)
                Text("Calories")
                    .font(.system(.caption2, design: .default, weight: .bold))
                    .foregroundStyle(AppTheme.mutedText)
            }
            Text("\(Int(current.rounded())) / \(Int(goal))")
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.titleText)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.subtleFill)
                    Capsule()
                        .fill(AppTheme.primaryBlue.opacity(0.85))
                        .frame(width: geo.size.width * min(1, progress))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.subtleFill.opacity(AppTheme.isDarkModeEnabled ? 0.45 : 0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Calories \(Int(current)) of \(Int(goal))")
    }

    private func remainingHint(protein: Double, goalP: Double, calories: Double, goalCal: Double) -> some View {
        let pLeft = max(0, goalP - protein)
        let cLeft = max(0, goalCal - calories)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Left today")
                .font(.system(.caption2, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.mutedText)
            Text("\(Int(pLeft.rounded()))g protein")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.bodyText)
            Text("\(Int(cLeft.rounded())) kcal")
                .font(.system(.caption, design: .default, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.subtleFill.opacity(AppTheme.isDarkModeEnabled ? 0.45 : 0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
