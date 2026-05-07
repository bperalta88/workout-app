import SwiftUI
import SwiftData

struct CharacterSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlayerStats.id) private var statsRows: [PlayerStats]
    @State private var lastSeenLevel: Int = 1
    @State private var showTransformationFlash = false
    @State private var showTransformationCutscene = false
    @State private var cutsceneStage: RPGProgressionEngine.FormStage = .kidGohan
    @State private var cutsceneTitle: String = ""

    private var stats: PlayerStats? { statsRows.first }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let stats {
                        heroCard(stats: stats)
                    } else {
                        heroCard(stats: nil)
                    }
                    if let stats {
                        statAllocatorCard(stats: stats)
                        buildSummaryCard(stats: stats)
                        progressionCard(stats: stats)
                    } else {
                        Text("Character profile missing. Reopen app to initialize.")
                            .foregroundStyle(AppTheme.mutedText)
                            .padding(14)
                            .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
                    }
                }
            }
            if showTransformationCutscene {
                TransformationCutsceneOverlay(
                    stage: cutsceneStage,
                    title: cutsceneTitle
                ) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        showTransformationCutscene = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                .zIndex(10)
            }
        }
        .task {
            PlayerStats.ensureExists(in: modelContext)
            try? modelContext.save()
            if let stats {
                lastSeenLevel = RPGProgressionEngine.level(forXP: stats.totalXP)
            }
        }
        .onChange(of: stats?.totalXP ?? 0) { _, newXP in
            let newLevel = RPGProgressionEngine.level(forXP: newXP)
            let newStage = RPGProgressionEngine.formStage(forLevel: newLevel)
            let oldStage = RPGProgressionEngine.formStage(forLevel: lastSeenLevel)
            guard newLevel > lastSeenLevel else { return }
            lastSeenLevel = newLevel
            withAnimation(.easeOut(duration: 0.2)) {
                showTransformationFlash = true
            }
            if newStage != oldStage {
                cutsceneStage = newStage
                cutsceneTitle = "TRANSFORMATION UNLOCKED: \(formLabel(newStage).uppercased())"
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    showTransformationCutscene = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        showTransformationCutscene = false
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showTransformationFlash = false
                }
            }
        }
    }

    private func heroCard(stats: PlayerStats?) -> some View {
        let xp = stats?.totalXP ?? 0
        let level = RPGProgressionEngine.level(forXP: xp)
        let stage = RPGProgressionEngine.formStage(forLevel: level)
        let powerLevel = (level * 120) + (stats.map { ($0.strengthStat + $0.hypertrophyStat + $0.recoveryStat) * 35 } ?? 0) + (xp / 5)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                RPGFighterAvatar(stage: stage, isTransforming: showTransformationFlash)
                    .frame(width: 130, height: 160)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Character Sheet")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.72, green: 0.85, blue: 1))

                    Text(stats.map(RPGProgressionEngine.classTitle(for:)) ?? "Unranked")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(red: 0.84, green: 0.72, blue: 1))

                    Text("Level \(level) • \(formLabel(stage))")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))

                    Text("Anime-inspired fighter evolution. Level up to unlock the next form.")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Power Level: \(powerLevel.formatted(.number.grouping(.automatic)))")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.5))
                            .tracking(0.4)
                        ProgressView(value: min(1, Double(RPGProgressionEngine.xpIntoCurrentLevel(xp: xp)) / Double(max(1, RPGProgressionEngine.xpNeededForNextLevel(xp: xp)))))
                            .tint(Color(red: 0.95, green: 0.75, blue: 0.28))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.12, green: 0.03, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(Color(red: 0.35, green: 0.52, blue: 1).opacity(0.5), lineWidth: 1)
        }
        .overlay {
            if showTransformationFlash {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color(red: 1, green: 0.85, blue: 0.4).opacity(0.22),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .transition(.opacity)
            }
        }
    }

    private func statAllocatorCard(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Available Points")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Text("\(stats.availableStatPoints)")
                    .font(.system(.title3, design: .default, weight: .bold))
                    .foregroundStyle(Color(red: 0.68, green: 0.86, blue: 1))
            }

            statRow(title: "Strength", value: stats.strengthStat, icon: "figure.strengthtraining.traditional") {
                spendPoint(on: \.strengthStat)
            } onMinus: {
                refundPoint(from: \.strengthStat)
            }
            statRow(title: "Hypertrophy", value: stats.hypertrophyStat, icon: "bolt.heart.fill") {
                spendPoint(on: \.hypertrophyStat)
            } onMinus: {
                refundPoint(from: \.hypertrophyStat)
            }
            statRow(title: "Recovery", value: stats.recoveryStat, icon: "leaf.fill") {
                spendPoint(on: \.recoveryStat)
            } onMinus: {
                refundPoint(from: \.recoveryStat)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func buildSummaryCard(stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Build Effects")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.titleText)
            Text(buildDescription(stats: stats))
                .font(.system(.subheadline, design: .default, weight: .medium))
                .foregroundStyle(AppTheme.bodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func progressionCard(stats: PlayerStats) -> some View {
        let level = RPGProgressionEngine.level(forXP: stats.totalXP)
        let intoLevel = RPGProgressionEngine.xpIntoCurrentLevel(xp: stats.totalXP)
        let needed = RPGProgressionEngine.xpNeededForNextLevel(xp: stats.totalXP)
        let progress = min(1, Double(intoLevel) / Double(max(1, needed)))

        return VStack(alignment: .leading, spacing: 8) {
            Text("Progression")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.titleText)

            Label("Level \(level) • Total XP: \(stats.totalXP)", systemImage: "sparkles")
                .foregroundStyle(AppTheme.bodyText)
            ProgressView(value: progress)
                .tint(Color(red: 0.42, green: 0.66, blue: 1))
            Text("\(intoLevel)/\(needed) XP to next level")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)

            Label(
                "Accessory XP Multiplier: +\(Int((RPGProgressionEngine.hypertrophyXPMultiplier(stat: stats.hypertrophyStat) - 1) * 100))%",
                systemImage: "chart.line.uptrend.xyaxis"
            )
            .foregroundStyle(AppTheme.bodyText)
            Label(
                "Passive Rest-Day XP: \(RPGProgressionEngine.passiveRestDayXPBase(recoveryStat: stats.recoveryStat))",
                systemImage: "moon.zzz.fill"
            )
            .foregroundStyle(AppTheme.bodyText)
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func statRow(
        title: String,
        value: Int,
        icon: String,
        onPlus: @escaping () -> Void,
        onMinus: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(Color(red: 0.57, green: 0.73, blue: 1))
            Text(title)
                .foregroundStyle(AppTheme.titleText)
            Spacer()
            Button(action: onMinus) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(value > 0 ? Color.red.opacity(0.85) : AppTheme.mutedText.opacity(0.5))
            .disabled(value == 0)
            Text("\(value)")
                .frame(minWidth: 30)
                .font(.system(.body, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.titleText)
            Button(action: onPlus) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle((stats?.availableStatPoints ?? 0) > 0 ? Color.green.opacity(0.9) : AppTheme.mutedText.opacity(0.5))
            .disabled((stats?.availableStatPoints ?? 0) <= 0)
        }
    }

    private func buildDescription(stats: PlayerStats) -> String {
        let strongest = [
            ("Strength", stats.strengthStat),
            ("Hypertrophy", stats.hypertrophyStat),
            ("Recovery", stats.recoveryStat)
        ].max(by: { $0.1 < $1.1 })?.0 ?? "Balanced"

        let strengthReduction = max(0, stats.strengthStat / 5)
        let hypertrophyBonus = Int((RPGProgressionEngine.hypertrophyXPMultiplier(stat: stats.hypertrophyStat) - 1) * 100)
        let restXP = RPGProgressionEngine.passiveRestDayXPBase(recoveryStat: stats.recoveryStat)

        return "\(strongest) build: Heavy compounds suggest ~\(strengthReduction) fewer target reps; accessory sets grant +\(hypertrophyBonus)% XP; full rest days grant \(restXP) passive XP."
    }

    private func spendPoint(on keyPath: ReferenceWritableKeyPath<PlayerStats, Int>) {
        guard let stats, stats.availableStatPoints > 0 else { return }
        stats.availableStatPoints -= 1
        stats[keyPath: keyPath] += 1
        try? modelContext.save()
    }

    private func refundPoint(from keyPath: ReferenceWritableKeyPath<PlayerStats, Int>) {
        guard let stats, stats[keyPath: keyPath] > 0 else { return }
        stats[keyPath: keyPath] -= 1
        stats.availableStatPoints += 1
        try? modelContext.save()
    }

    private func formLabel(_ stage: RPGProgressionEngine.FormStage) -> String {
        switch stage {
        case .kidGohan: return "Kid Gohan"
        case .superSaiyanGohan: return "Super Saiyan Gohan"
        case .teenSuperSaiyan2: return "Teen Gohan (SSJ2)"
        case .ultimateGohan: return "Ultimate Gohan"
        case .mysticAwakened: return "Mystic Awakened"
        case .beastGohan: return "Beast Gohan"
        }
    }
}

private struct RPGFighterAvatar: View {
    var stage: RPGProgressionEngine.FormStage
    var isTransforming: Bool

    @State private var auraPulse = false
    @State private var bob = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            auraColor.opacity(auraPulse ? 0.50 : 0.25),
                            auraColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .scaleEffect(auraPulse ? 1.06 : 0.92)

            PixelFighterSprite(
                stage: stage,
                hairColor: hairColor,
                auraColor: auraColor,
                chestColor: chestColor
            )
            .frame(width: 84, height: 112)
            .shadow(color: auraColor.opacity(0.4), radius: 8)
        }
        .offset(y: bob ? -2 : 2)
        .scaleEffect(isTransforming ? 1.08 : 1)
        .animation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true), value: auraPulse)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: bob)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isTransforming)
        .onAppear {
            auraPulse = true
            bob = true
        }
    }

    private var auraColor: Color {
        switch stage {
        case .kidGohan: return Color(red: 0.24, green: 0.58, blue: 1)
        case .superSaiyanGohan: return Color(red: 1.0, green: 0.94, blue: 0.38)
        case .teenSuperSaiyan2: return Color(red: 1.0, green: 0.86, blue: 0.22)
        case .ultimateGohan: return Color(red: 0.62, green: 0.68, blue: 1.0)
        case .mysticAwakened: return Color(red: 0.78, green: 0.5, blue: 1.0)
        case .beastGohan: return Color(red: 1.0, green: 0.25, blue: 0.35)
        }
    }

    private var hairColor: Color {
        switch stage {
        case .kidGohan: return Color(red: 0.14, green: 0.14, blue: 0.16)
        case .superSaiyanGohan: return Color(red: 0.99, green: 0.88, blue: 0.26)
        case .teenSuperSaiyan2: return Color(red: 1.0, green: 0.9, blue: 0.32)
        case .ultimateGohan: return Color(red: 0.14, green: 0.14, blue: 0.16)
        case .mysticAwakened: return Color(red: 0.16, green: 0.16, blue: 0.2)
        case .beastGohan: return Color(red: 0.92, green: 0.92, blue: 0.97)
        }
    }

    private var chestColor: Color {
        switch stage {
        case .kidGohan: return Color(red: 0.28, green: 0.24, blue: 0.62)
        case .superSaiyanGohan: return Color(red: 0.34, green: 0.2, blue: 0.66)
        case .teenSuperSaiyan2: return Color(red: 0.3, green: 0.16, blue: 0.58)
        case .ultimateGohan: return Color(red: 0.26, green: 0.20, blue: 0.54)
        case .mysticAwakened: return Color(red: 0.32, green: 0.18, blue: 0.62)
        case .beastGohan: return Color(red: 0.36, green: 0.12, blue: 0.55)
        }
    }
}

private struct PixelFighterSprite: View {
    var stage: RPGProgressionEngine.FormStage
    var hairColor: Color
    var auraColor: Color
    var chestColor: Color

    // 14x18 grid sprites (original, anime-inspired — not a franchise asset).
    private var sprite: [String] {
        switch stage {
        case .kidGohan:
            return [
                "..hh..hh..hh..",
                "...hhhhhhhh...",
                "..hhhhh.hhhh..",
                "...ssssssss....",
                "...sseessss....",
                "...ssssssss....",
                "..ccccttcccc...",
                "..ccccttcccc...",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                "..ccccttcccc...",
                "...ll....ll....",
                "...ll....ll....",
                "...ll....ll....",
                "..bbb....bbb...",
                "...............",
                "..............."
            ]
        case .superSaiyanGohan:
            return [
                ".h..hh..hh..h..",
                "..hhhhhhhhhh...",
                ".hhhhhhhhh.hh..",
                "...ssssssss....",
                "...sseessss....",
                "...ssssssss....",
                "..ccccttcccc...",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                "..ccccttcccc...",
                "...ccccttccc....",
                "...ll....ll....",
                "..lll....lll...",
                "...ll....ll....",
                "..bbb....bbb...",
                "...............",
                "..............."
            ]
        case .teenSuperSaiyan2:
            return [
                ".h..hh..hh..h..",
                ".hhhhhhhhhhhh..",
                "hhh.hhhhhh.hhhh",
                "...ssssssss....",
                "...sseessss....",
                "...ssssssss....",
                "..ccccttcccc...",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                "..ccccttcccc...",
                "..lll....lll...",
                "..lll....lll...",
                "...ll....ll....",
                "..bbb....bbb...",
                "...............",
                "..............."
            ]
        case .ultimateGohan:
            return [
                "..hh..hh..hh..",
                "...hhhhhhhh...",
                "..hhhhh.hhhh..",
                "...ssssssss....",
                "...sseessss....",
                "...ssssssss....",
                "..ccccttcccc...",
                "..ccccttcccc...",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                "..ccccttcccc...",
                "..lll....lll...",
                "...ll....ll....",
                "...ll....ll....",
                "..bbb....bbb...",
                "...............",
                "..............."
            ]
        case .mysticAwakened:
            return [
                "..hh..hh..hh..",
                "..hhhhhhhhhh..",
                ".hhhhhhhhh.hh.",
                "...ssssssss....",
                "...sseessss....",
                "...ssssssss....",
                "..ccccttcccc...",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                "..ccccttcccc...",
                "..ccccttcccc...",
                "..lll....lll...",
                "..lll....lll...",
                "...ll....ll....",
                "..bbb....bbb...",
                "...............",
                "..............."
            ]
        case .beastGohan:
            return [
                ".hhh.hhh.hhh...",
                "hhhhhhhhhhhhh..",
                "hhh.hhhhhh.hhhh",
                "...ssssssss....",
                "...sseessss....",
                "...ssssssss....",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                ".accccttcccca..",
                "..ccccttcccc...",
                "..lll....lll...",
                "..lll....lll...",
                "..lll....lll...",
                "..bbb....bbb...",
                "...............",
                "..............."
            ]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let rows = sprite.count
            let cols = sprite.first?.count ?? 1
            let px = min(geo.size.width / CGFloat(cols), geo.size.height / CGFloat(rows))

            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        let row = Array(sprite[r])
                        ForEach(0..<cols, id: \.self) { c in
                            let ch = row[c]
                            Rectangle()
                                .fill(color(for: ch))
                                .frame(width: px, height: px)
                        }
                    }
                }
            }
            .drawingGroup()
            .overlay(
                Rectangle()
                    .stroke(auraColor.opacity(0.22), lineWidth: 1)
            )
        }
    }

    private func color(for token: Character) -> Color {
        switch token {
        case "h": return hairColor
        case "s": return Color(red: 0.95, green: 0.79, blue: 0.66) // skin
        case "e": return Color.black // eyes
        case "c": return chestColor
        case "a": return chestColor.opacity(0.85) // arms
        case "t": return Color(red: 0.91, green: 0.72, blue: 0.35) // belt detail
        case "l": return Color(red: 0.12, green: 0.16, blue: 0.24) // legs
        case "b": return Color(red: 0.08, green: 0.1, blue: 0.14) // boots
        default: return .clear
        }
    }
}

private struct TransformationCutsceneOverlay: View {
    var stage: RPGProgressionEngine.FormStage
    var title: String
    var onDismiss: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.82))
                .ignoresSafeArea()

            VStack(spacing: 14) {
                RPGFighterAvatar(stage: stage, isTransforming: true)
                    .frame(width: 170, height: 210)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )

                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.55))
                    .tracking(0.9)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)

                Text("Power surges. Stats scale harder in higher forms.")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))

                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(red: 1, green: 0.85, blue: 0.35))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.06, blue: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color(red: 1, green: 0.65, blue: 0.25).opacity(pulse ? 0.85 : 0.35), lineWidth: pulse ? 2.6 : 1.4)
                    )
                    .shadow(color: Color(red: 1, green: 0.45, blue: 0.18).opacity(0.35), radius: 22)
            )
            .scaleEffect(pulse ? 1.01 : 0.99)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
        }
        .onTapGesture { onDismiss() }
    }
}
