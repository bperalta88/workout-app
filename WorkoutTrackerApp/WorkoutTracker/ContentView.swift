import SwiftUI
import SwiftData
import HealthKit
import Charts
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

enum AppAppearanceMode: String, CaseIterable {
    case dark
    case light

    var label: String { rawValue.capitalized }

    var preferredColorScheme: ColorScheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }
}

enum AppTheme {
    private static let modeKey = "appearanceMode"

    static var isDarkModeEnabled: Bool {
        let raw = UserDefaults.standard.string(forKey: modeKey) ?? AppAppearanceMode.dark.rawValue
        return AppAppearanceMode(rawValue: raw) != .light
    }

    static var background: Color { isDarkModeEnabled ? .black : Color(red: 0.976, green: 0.978, blue: 0.982) }
    static var cardBackground: Color { isDarkModeEnabled ? Color(red: 0.07, green: 0.08, blue: 0.10) : .white }
    static var titleText: Color { isDarkModeEnabled ? .white : Color(red: 0.09, green: 0.10, blue: 0.12) }
    static var bodyText: Color { isDarkModeEnabled ? Color.white.opacity(0.78) : Color(red: 0.38, green: 0.40, blue: 0.44) }
    static var mutedText: Color { isDarkModeEnabled ? Color.white.opacity(0.55) : Color(red: 0.55, green: 0.57, blue: 0.62) }
    /// Cyan / teal accent (matches mockups).
    static var primaryBlue: Color { isDarkModeEnabled ? Color(red: 0.16, green: 0.78, blue: 0.90) : Color(red: 0.16, green: 0.44, blue: 0.92) }
    static var accentLime: Color { isDarkModeEnabled ? Color(red: 0.65, green: 0.90, blue: 0.22) : Color.green }
    static var softInput: Color { isDarkModeEnabled ? Color(red: 0.09, green: 0.10, blue: 0.13) : Color(red: 0.96, green: 0.97, blue: 0.99) }
    static var darkSurface: Color { Color(red: 0.08, green: 0.10, blue: 0.14) }
    static var subtleFill: Color { isDarkModeEnabled ? Color.white.opacity(0.06) : Color.black.opacity(0.035) }
    static var cardBorder: Color { isDarkModeEnabled ? Color.white.opacity(0.08) : Color.black.opacity(0.06) }

    static let cardCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 10

    static var cardShadow: Color { isDarkModeEnabled ? Color.black.opacity(0.35) : Color.black.opacity(0.045) }
    static var cardShadowRadius: CGFloat { isDarkModeEnabled ? 10 : 8 }
    static var cardShadowY: CGFloat { isDarkModeEnabled ? 4 : 2 }
}

enum WeightUnit: String, CaseIterable {
    case lb
    case kg

    var label: String { rawValue.uppercased() }
}

enum WeightDisplay {
    static func converted(_ pounds: Double, to unit: WeightUnit) -> Double {
        switch unit {
        case .lb: return pounds
        case .kg: return pounds * 0.45359237
        }
    }

    static func formatted(_ pounds: Double, unit: WeightUnit) -> String {
        let value = converted(pounds, to: unit)
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(unit.rawValue)"
        }
        return "\(String(format: "%.1f", value)) \(unit.rawValue)"
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutDay.dayIndex) private var workoutDays: [WorkoutDay]
    @Query(sort: \PersonalRecord.achievedAt, order: .reverse) private var personalRecords: [PersonalRecord]
    @Query(sort: \CompletedWorkoutSession.completedAt, order: .reverse) private var completedSessions: [CompletedWorkoutSession]
    @Query(sort: \MealLog.loggedAt, order: .reverse) private var mealLogs: [MealLog]
    @Query(sort: \DailyQuestClaim.claimedAt, order: .reverse) private var dailyQuestClaims: [DailyQuestClaim]

    /// Active training plan only (excludes imported history programs so Home/History aren’t duplicated).
    private var primaryWorkoutDays: [WorkoutDay] {
        PrimaryProgram.daysSorted(from: workoutDays)
    }
    @State private var selectedTab: HomeTab = .home
    @State private var showPRBoardSheet = false
    @State private var showCompletionCalendarSheet = false
    @StateObject private var stepSync = StepCountManager()
    @AppStorage("dailyStepGoal") private var dailyStepGoal = 10000
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal = 5
    @AppStorage("nutritionDailyProteinGoal") private var dailyProteinGoal = 170
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.dark.rawValue
    @AppStorage("didDismissOnboardingChecklist") private var didDismissOnboardingChecklist = false
    /// `Calendar` weekday when program Day 1 starts (1 = Sunday, 2 = Monday).
    @AppStorage("programWeekStartsOnWeekday") private var programWeekStartsOnWeekday = 2
    @State private var dailyQuestRewardMessage: String?
    @State private var questRewardPulse = false

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .dark
    }

    private var completedDayCount: Int {
        completedThisWeekCount
    }

    private var weeklyCompletion: Double {
        guard weeklyWorkoutGoal > 0 else { return 0 }
        return min(1, Double(completedThisWeekCount) / Double(weeklyWorkoutGoal))
    }

    private var totalExercises: Int {
        primaryWorkoutDays.reduce(0) { $0 + $1.exercises.count }
    }

    private var streakDays: Int {
        currentStreakDays
    }

    private var weeklyGoalProgressPercent: Int {
        guard weeklyWorkoutGoal > 0 else { return 0 }
        return min(100, Int((Double(completedThisWeekCount) / Double(weeklyWorkoutGoal)) * 100))
    }

    private var completedSessionDaySet: Set<Date> {
        let calendar = Calendar.current
        let days = primaryWorkoutDays.compactMap(\.sessionCompletedAt).map { calendar.startOfDay(for: $0) }
        return Set(days)
    }

    private var completedThisWeekCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let mondayOffset = (weekday + 5) % 7
        let weekStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -mondayOffset, to: now) ?? now)
        let tomorrowStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)

        let uniqueCompletedDays = Set(
            primaryWorkoutDays.compactMap { day -> Date? in
                guard let completed = day.sessionCompletedAt else { return nil }
                guard completed >= weekStart && completed < tomorrowStart else { return nil }
                return calendar.startOfDay(for: completed)
            }
        )
        return uniqueCompletedDays.count
    }

    private var currentStreakDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let startDay: Date
        if completedSessionDaySet.contains(today) {
            startDay = today
        } else if completedSessionDaySet.contains(yesterday) {
            startDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = startDay
        while completedSessionDaySet.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    private var stepGoalProgressPercent: Int {
        guard dailyStepGoal > 0 else { return 0 }
        return min(100, Int((Double(stepSync.stepCount) / Double(dailyStepGoal)) * 100))
    }

    /// Program day index (1…7) for the current calendar date, from Settings → week start.
    private var programDayIndexForToday: Int {
        PrimaryProgram.programDayIndex(weekStartsOnWeekday: programWeekStartsOnWeekday)
    }

    /// The program template row for **today’s calendar slot** (not “next incomplete day”).
    private var todaysProgramWorkoutDay: WorkoutDay? {
        primaryWorkoutDays.first { $0.dayIndex == programDayIndexForToday }
    }

    /// `true` when today’s mapped workout was completed **today** (same calendar day), so we don’t roll the UI to the next template or block next week’s session.
    private var finishedTodaysProgramWorkout: Bool {
        completedWorkoutToday != nil
    }

    /// Most recently completed workout today (across all primary program days).
    private var completedWorkoutToday: WorkoutDay? {
        primaryWorkoutDays
            .filter { day in
                guard let t = day.sessionCompletedAt else { return false }
                return Calendar.current.isDateInToday(t)
            }
            .sorted { ($0.sessionCompletedAt ?? .distantPast) > ($1.sessionCompletedAt ?? .distantPast) }
            .first
    }

    /// Only the workout due **today**; after you finish today, this is `nil` until the next calendar training day.
    private var nextWorkoutDay: WorkoutDay? {
        // If any workout is already completed today, don't suggest another plan for today.
        if completedWorkoutToday != nil { return nil }
        guard let d = todaysProgramWorkoutDay else { return nil }
        if let completedAt = d.sessionCompletedAt, Calendar.current.isDateInToday(completedAt) {
            return nil
        }
        return d
    }

    private var nextPlannedExerciseName: String? {
        guard let nextWorkoutDay else { return nil }
        return firstUpcomingExerciseName(in: nextWorkoutDay)
    }

    /// Next exercise the user still needs to complete for this day (for "Today's Plan" / session preview).
    private func firstUpcomingExerciseName(in day: WorkoutDay) -> String? {
        for exercise in day.sortedExercises {
            if exercise.kind == .cardio {
                if !exercise.cardioCompleted { return exercise.name }
            } else if exercise.sortedSetLogs.contains(where: { !$0.isCompleted }) {
                return exercise.name
            }
        }
        return day.sortedExercises.first?.name
    }

    private var onboardingItems: [OnboardingItem] {
        [
            OnboardingItem(
                title: "Set your weekly goal",
                isDone: weeklyWorkoutGoal > 0
            ),
            OnboardingItem(
                title: "Set your daily step goal",
                isDone: dailyStepGoal >= 2000
            ),
            OnboardingItem(
                title: "Enable Health step sync",
                isDone: stepSync.isAuthorized
            )
        ]
    }

    private var onboardingComplete: Bool {
        onboardingItems.allSatisfy(\.isDone)
    }

    private var calendarDays: [CalendarDay] {
        let cal = Calendar.current
        let today = Date()
        let weekday = max(1, cal.component(.weekday, from: today))
        let symbols = cal.shortWeekdaySymbols
        return (0..<7).map { idx in
            let symbol = symbols[idx]
            let dayNumber = cal.component(.day, from: cal.date(byAdding: .day, value: idx - (weekday - 1), to: today) ?? today)
            return CalendarDay(label: symbol, dayNumber: dayNumber, isToday: idx + 1 == weekday)
        }
    }

    private struct DailyQuestState: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let xpReward: Int
        let isComplete: Bool
        let destinationTab: HomeTab
    }

    private var todayStart: Date { Calendar.current.startOfDay(for: .now) }

    private var todaysMeals: [MealLog] {
        mealLogs.filter { Calendar.current.isDateInToday($0.loggedAt) }
    }

    private var todaysProteinTotal: Double {
        todaysMeals.reduce(0) { $0 + $1.proteinG }
    }

    private var todayQuestClaimIDs: Set<String> {
        Set(
            dailyQuestClaims
                .filter { Calendar.current.isDate($0.claimedAt, inSameDayAs: todayStart) }
                .map(\.questID)
        )
    }

    private var todaysQuestClaims: [DailyQuestClaim] {
        dailyQuestClaims
            .filter { Calendar.current.isDate($0.claimedAt, inSameDayAs: todayStart) }
            .sorted { $0.claimedAt > $1.claimedAt }
    }

    private var dailyQuestStates: [DailyQuestState] {
        [
            DailyQuestState(
                id: "quest_log_meal",
                title: "Fuel Logged",
                subtitle: "Log at least one meal today",
                xpReward: 15,
                isComplete: !todaysMeals.isEmpty,
                destinationTab: .nutrition
            ),
            DailyQuestState(
                id: "quest_hit_protein",
                title: "Protein Hunter",
                subtitle: "Hit \(dailyProteinGoal)g protein (\(Int(todaysProteinTotal))/\(dailyProteinGoal)g)",
                xpReward: 30,
                isComplete: todaysProteinTotal >= Double(max(1, dailyProteinGoal)),
                destinationTab: .nutrition
            ),
            DailyQuestState(
                id: "quest_train",
                title: "Battle Cleared",
                subtitle: "Complete today's workout session",
                xpReward: 40,
                isComplete: completedWorkoutToday != nil,
                destinationTab: .workouts
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mainTabContent
                    .background(AppTheme.background.ignoresSafeArea())

                BottomTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
            .navigationTitle(tabTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedTab == .home {
                        Button {
                            showCompletionCalendarSheet = true
                        } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryBlue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open completion calendar")
                    } else if selectedTab == .more {
                        Button {
                            appearanceModeRaw = (appearanceMode == .dark ? AppAppearanceMode.light.rawValue : AppAppearanceMode.dark.rawValue)
                        } label: {
                            Image(systemName: appearanceMode == .dark ? "sun.max.fill" : "moon.stars.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryBlue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Toggle appearance")
                    }
                }
            }
            .sheet(isPresented: $showPRBoardSheet) {
                NavigationStack {
                    PRBoardView(records: personalRecords)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .background(AppTheme.background.ignoresSafeArea())
                        .navigationTitle("PR Board")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showPRBoardSheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showCompletionCalendarSheet) {
                NavigationStack {
                    CompletionCalendarSheet(workoutDays: workoutDays)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .background(AppTheme.background.ignoresSafeArea())
                        .navigationTitle("Workout Calendar")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showCompletionCalendarSheet = false }
                            }
                        }
                }
            }
        }
        .task {
            await stepSync.requestAccessAndRefresh()
            grantPassiveRecoveryXPIfEligible()
            evaluateDailyQuestRewards()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await stepSync.refreshTodaySteps()
                    await stepSync.refreshWeeklySteps()
                    grantPassiveRecoveryXPIfEligible()
                    evaluateDailyQuestRewards()
                }
            }
        }
        .onChange(of: mealLogs.count) { _, _ in
            evaluateDailyQuestRewards()
        }
        .onChange(of: completedSessions.count) { _, _ in
            evaluateDailyQuestRewards()
        }
        .preferredColorScheme(appearanceMode.preferredColorScheme)
    }

    @ViewBuilder
    private var mainTabContent: some View {
        switch selectedTab {
        case .home:
            homeDashboard
        case .nutrition:
            NutritionTabView()
                .padding(.bottom, 110)
        case .workouts:
            WorkoutLibraryView(primaryDays: primaryWorkoutDays)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 110)
        case .progress:
            ProgressTabView(
                completionPercent: Int(weeklyCompletion * 100),
                weeklyGoalPercent: weeklyGoalProgressPercent,
                stepGoalPercent: stepGoalProgressPercent,
                completedDayCount: completedDayCount,
                totalDays: primaryWorkoutDays.count,
                totalExercises: totalExercises,
                stepCount: stepSync.stepCount,
                personalRecordCount: personalRecords.count,
                weeklyWorkoutGoal: weeklyWorkoutGoal,
                dailyStepGoal: dailyStepGoal,
                weeklyStepPoints: stepSync.weeklyStepPoints,
                completedWorkoutPoints: weeklyCompletionPoints,
                completedSessions: completedSessions
            )
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 110)
        case .more:
            MoreTabView(completedSessions: completedSessions, stepSync: stepSync)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 110)
        }
    }

    private func grantPassiveRecoveryXPIfEligible() {
        _ = PlayerStats.awardPassiveRecoveryXPIfEligible(
            allWorkoutDays: primaryWorkoutDays,
            in: modelContext
        )
    }

    private func evaluateDailyQuestRewards() {
        var awardedXP = 0
        for quest in dailyQuestStates where quest.isComplete {
            let awarded = PlayerStats.awardDailyQuestXPIfNeeded(
                questID: quest.id,
                xp: quest.xpReward,
                in: modelContext
            )
            if awarded { awardedXP += quest.xpReward }
        }
        if awardedXP > 0 {
            dailyQuestRewardMessage = "Quest complete: +\(awardedXP) XP"
            questRewardPulse = true
#if canImport(UIKit)
            let feedback = UINotificationFeedbackGenerator()
            feedback.prepare()
            feedback.notificationOccurred(.success)
#endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                questRewardPulse = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if dailyQuestRewardMessage == "Quest complete: +\(awardedXP) XP" {
                    dailyQuestRewardMessage = nil
                }
            }
            try? modelContext.save()
        }
    }

    private var weeklyCompletionPoints: [CompletionPoint] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<7).reversed().map { offset in
            let dayDate = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let start = calendar.startOfDay(for: dayDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? dayDate
            let completedCount = primaryWorkoutDays.filter { day in
                guard let completed = day.sessionCompletedAt else { return false }
                return completed >= start && completed < end
            }.count
            return CompletionPoint(date: dayDate, completedSessions: completedCount)
        }
    }

    private var homeDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                homeHeroCard
                homeDailyQuestCard
                MacroDashboardView {
                    selectedTab = .nutrition
                }
                homeTodayPlanCard
                homeCalendarStrip
                homeMetricGrid
                homeQuickActionsRow
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
    }

    @ViewBuilder
    private var homeDailyQuestCard: some View {
        let unclaimed = dailyQuestStates.filter { !todayQuestClaimIDs.contains($0.id) }
        let actionable = unclaimed.filter { !$0.isComplete }
        let completedCount = dailyQuestStates.count - unclaimed.count
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Quests")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Text("\(completedCount)/\(dailyQuestStates.count)")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(completedCount == dailyQuestStates.count ? .green : AppTheme.primaryBlue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background((completedCount == dailyQuestStates.count ? Color.green : AppTheme.primaryBlue).opacity(0.12), in: Capsule())
            }

            if let message = dailyQuestRewardMessage {
                Text(message)
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.green)
                    .scaleEffect(questRewardPulse ? 1.05 : 1.0)
                    .animation(.spring(response: 0.26, dampingFraction: 0.62), value: questRewardPulse)
                    .transition(.opacity)
            }

            if actionable.isEmpty {
                Text("All quests completed today. XP claimed - come back tomorrow for new quests.")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                ForEach(actionable) { quest in
                    Button {
                        selectedTab = quest.destinationTab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(quest.title)
                                    .font(.system(.subheadline, design: .default, weight: .semibold))
                                    .foregroundStyle(AppTheme.titleText)
                                Text(quest.subtitle)
                                    .font(.system(.caption, design: .default, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                            Spacer()
                            Text("+\(quest.xpReward) XP")
                                .font(.system(.caption, design: .default, weight: .bold))
                                .foregroundStyle(AppTheme.accentLime)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .move(edge: .leading))))
                }
            }

            if !todaysQuestClaims.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Claimed today")
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedText)
                    ForEach(todaysQuestClaims, id: \.persistentModelID) { claim in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.green)
                            Text(questTitle(for: claim.questID))
                                .font(.system(.caption, design: .default, weight: .medium))
                                .foregroundStyle(AppTheme.bodyText)
                            Spacer()
                            Text("+\(claim.xpAwarded) XP")
                                .font(.system(.caption, design: .default, weight: .bold))
                                .foregroundStyle(AppTheme.accentLime)
                        }
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
        .animation(.easeInOut(duration: 0.24), value: actionable.count)
        .animation(.easeInOut(duration: 0.24), value: todaysQuestClaims.count)
        .animation(.easeInOut(duration: 0.2), value: dailyQuestRewardMessage)
    }

    private func questTitle(for questID: String) -> String {
        dailyQuestStates.first(where: { $0.id == questID })?.title ?? "Daily Quest"
    }

    private var homeHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Good morning")
                .font(.system(.caption, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)

            Text("Ready to train?")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.titleText)

            if let done = completedWorkoutToday {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("Completed today: \(done.focus)")
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.titleText.opacity(0.92))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.green.opacity(AppTheme.isDarkModeEnabled ? 0.12 : 0.10), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.green.opacity(0.28), lineWidth: 1))
            }

            if let day = nextWorkoutDay {
                NavigationLink {
                    WorkoutSessionView(day: day)
                } label: {
                    Text("Start workout")
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(.black.opacity(AppTheme.isDarkModeEnabled ? 0.85 : 0.74))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(AppTheme.primaryBlue, in: Capsule())
                }
                .buttonStyle(.plain)
            } else if let done = completedWorkoutToday {
                VStack(alignment: .leading, spacing: 6) {
                    Text("All done for today")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("You finished \(done.focus). Next session shows on your next training day.")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if primaryWorkoutDays.isEmpty {
                Text("Seed a program to start.")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.bodyText)
            } else {
                Text("No workout is mapped to today’s program slot. Open Workouts to pick a day, or check Settings → week start.")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private var homeTodayPlanCard: some View {
        Group {
            if let day = nextWorkoutDay {
                NavigationLink {
                    WorkoutSessionView(day: day)
                } label: {
                    todayPlanCardBodyForMock(day: day)
                }
                .buttonStyle(.plain)
            } else if let done = completedWorkoutToday {
                todayPlanCardRestBody(completedDay: done)
            } else {
                todayPlanCardBodyForMock(day: nil)
            }
        }
    }

    private func todayPlanCardBodyForMock(day: WorkoutDay?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's plan")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.subtleFill, in: Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.primaryBlue.opacity(0.45), lineWidth: 1))
            }

            if let day {
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.primaryBlue.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "doc.text")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryBlue)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.focus)
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(AppTheme.titleText)
                        Text("\(day.exercises.count) exercises • \(estimatedMinutesString(for: day))")
                            .font(.system(.caption, design: .default, weight: .medium))
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText.opacity(0.8))
                }
            } else if primaryWorkoutDays.isEmpty {
                Text("No workout days found. Import or seed a plan to begin.")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Text("No session is assigned to today’s calendar slot. Check Settings for which weekday is program Day 1, or open the Workouts tab.")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func todayPlanCardRestBody(completedDay: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's plan")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.green.opacity(0.35), lineWidth: 1))
            }

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.green)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing else due today")
                        .font(.system(.body, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.titleText)
                    Text("You already completed \(completedDay.focus) (Day \(completedDay.dayIndex)). The next session for your calendar day will show here when that day arrives.")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                }
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func estimatedMinutesString(for day: WorkoutDay) -> String {
        if let mins = estimatedMinutes(for: day) { return "\(mins) min" }
        return "— min"
    }

    private func estimatedMinutes(for day: WorkoutDay) -> Int? {
        // Best-effort: look for first number in cardio target, else fallback.
        let text = (day.exercises.first { $0.kind == .cardio }?.targetSetsReps ?? "")
        let digits = text.split(whereSeparator: { !$0.isNumber }).first
        if let digits, let v = Int(digits) { return v }
        return nil
    }

    private var homeCalendarStrip: some View {
        HStack(spacing: 10) {
            ForEach(calendarDays) { day in
                VStack(spacing: 4) {
                    Text(day.label)
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(day.isToday ? AppTheme.primaryBlue : AppTheme.mutedText)
                    Text("\(day.dayNumber)")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.titleText)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .strokeBorder(day.isToday ? AppTheme.primaryBlue : Color.clear, lineWidth: 2)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private var homeMetricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            HomeMetricTile(
                title: "Streak",
                value: "\(streakDays)",
                valueSuffix: "days",
                icon: "flame.fill",
                iconTint: AppTheme.accentLime
            ) {
                HStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { idx in
                        Circle()
                            .fill(idx < min(streakDays, 7) ? AppTheme.accentLime : AppTheme.subtleFill)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            HomeMetricTile(
                title: "Exercises",
                value: "\(totalExercises)",
                valueSuffix: "completed",
                icon: "dumbbell",
                iconTint: AppTheme.primaryBlue,
                footer: { EmptyView() }
            )

            HomeMetricTile(
                title: "Weekly progress",
                value: "\(Int(weeklyCompletion * 100))%",
                valueSuffix: "",
                icon: "chart.pie.fill",
                iconTint: AppTheme.primaryBlue
            ) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(AppTheme.subtleFill, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: weeklyCompletion)
                            .stroke(AppTheme.primaryBlue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Goal")
                            .font(.system(.caption2, design: .default, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedText)
                        Text("\(completedDayCount) / \(weeklyWorkoutGoal)")
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(AppTheme.titleText)
                    }
                    Spacer()
                }
            }

            HomeMetricTile(
                title: "Steps",
                value: "\(stepSync.stepCount.formatted(.number.grouping(.automatic)))",
                valueSuffix: "steps",
                icon: "figure.walk",
                iconTint: AppTheme.primaryBlue
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: min(1, Double(stepSync.stepCount) / Double(max(1, dailyStepGoal))))
                        .tint(AppTheme.primaryBlue)
                    Text("\(stepGoalProgressPercent)% of \(dailyStepGoal.formatted(.number.grouping(.automatic)))")
                        .font(.system(.caption2, design: .default, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                }
            }
        }
    }

    private var homeQuickActionsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick actions")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.titleText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let day = nextWorkoutDay {
                        NavigationLink {
                            WorkoutSessionView(day: day)
                        } label: {
                            HomeActionPill(title: "Log workout", icon: "plus")
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        selectedTab = .progress
                    } label: {
                        HomeActionPill(title: "Body stats", icon: "person.fill")
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedTab = .nutrition
                    } label: {
                        HomeActionPill(title: "Log meal", icon: "fork.knife")
                    }
                    .buttonStyle(.plain)

                    Button {
                        showPRBoardSheet = true
                    } label: {
                        HomeActionPill(title: "PR board", icon: "trophy.fill")
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedTab = .more
                    } label: {
                        HomeActionPill(title: "More", icon: "ellipsis.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private var onboardingChecklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Getting Started")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Button("Dismiss") {
                    didDismissOnboardingChecklist = true
                }
                .font(.system(.caption, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.primaryBlue)
            }
            ForEach(onboardingItems) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isDone ? .green : AppTheme.mutedText)
                    Text(item.title)
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                }
            }
            if onboardingComplete {
                Text("All set. You're ready to train.")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    @ViewBuilder
    private var todayPlanCard: some View {
        if let day = nextWorkoutDay {
            NavigationLink {
                WorkoutSessionView(day: day)
            } label: {
                todayPlanCardBody(day: day)
            }
            .buttonStyle(.plain)
        } else if let done = completedWorkoutToday {
            todayPlanCardBodyRest(completedDay: done)
        } else {
            todayPlanCardBody(day: nil)
        }
    }

    private func todayPlanCardBodyRest(completedDay: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                Text("Today's Plan")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Text("Done")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }
            Text("Nothing else due today — \(completedDay.focus) (Day \(completedDay.dayIndex)) is complete.")
                .font(.system(.subheadline, design: .default, weight: .regular))
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func todayPlanCardBody(day: WorkoutDay?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                Text("Today's Plan")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                if let day {
                    Text("Day \(day.dayIndex)")
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.subtleFill, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(AppTheme.primaryBlue.opacity(0.35), lineWidth: 1)
                        )
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText.opacity(0.75))
                }
            }

            if let day {
                Text(day.focus)
                    .font(.system(.title3, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                if let upcoming = firstUpcomingExerciseName(in: day) {
                    Label("Up next: \(upcoming)", systemImage: "figure.strengthtraining.traditional")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                        .labelStyle(.titleAndIcon)
                }
            } else if primaryWorkoutDays.isEmpty {
                Text("No workout days found. Import or seed a plan to begin.")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Text("No session mapped to today’s calendar slot.")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private var tabTitle: String {
        switch selectedTab {
        case .home: return "Home"
        case .workouts: return "Train"
        case .nutrition: return "Nutrition"
        case .progress: return "Progress"
        case .more: return "More"
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                )

            HStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.primaryBlue.opacity(0.85))
                    .frame(width: 4)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome back")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
                Text("Push your next PR")
                    .font(.system(size: 26, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.titleText)
                Text("\(totalExercises) exercises this week")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(AppTheme.bodyText)
            }
            .padding(20)
        }
        .frame(height: 148)
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private var calendarStrip: some View {
        HStack(spacing: 6) {
            ForEach(calendarDays) { day in
                VStack(spacing: 4) {
                    Text(day.label)
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundStyle(day.isToday ? AppTheme.primaryBlue : AppTheme.mutedText)
                    Text("\(day.dayNumber)")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.titleText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(day.isToday ? AppTheme.cardBackground : AppTheme.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            day.isToday ? AppTheme.primaryBlue.opacity(0.55) : AppTheme.cardBorder,
                            lineWidth: day.isToday ? 1.5 : 1
                        )
                )
            }
        }
    }

    private var progressDonutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Progress")
                .font(.system(.caption, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
                .textCase(.uppercase)
                .tracking(0.6)

            ZStack {
                Circle()
                    .stroke(AppTheme.subtleFill, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: weeklyCompletion)
                    .stroke(
                        AppTheme.primaryBlue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(weeklyCompletion * 100))%")
                        .font(.system(size: 22, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.titleText)
                    Text("Complete")
                        .font(.system(.caption2, design: .default, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                }
            }
            .frame(width: 118, height: 118)
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private var miniBarsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sessions")
                .font(.system(.caption, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(primaryWorkoutDays.prefix(6)).indices, id: \.self) { idx in
                    let day = primaryWorkoutDays[idx]
                    let barHeight: CGFloat = day.isCompleted ? 76 : CGFloat(26 + idx * 8)

                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(day.isCompleted ? AppTheme.primaryBlue : AppTheme.primaryBlue.opacity(0.18))
                            .frame(width: 18, height: barHeight)
                        Text("\(day.dayIndex)")
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(height: 110, alignment: .bottom)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private var workoutWeekSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Workout Week")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Text("\(Int(weeklyCompletion * 100))%")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryBlue)
            }

                    ForEach(primaryWorkoutDays, id: \.persistentModelID) { day in
                        NavigationLink {
                            WorkoutSessionView(day: day)
                        } label: {
                    DayCard(day: day)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.titleText)

            HStack(spacing: 10) {
                if let nextWorkoutDay {
                    NavigationLink {
                        WorkoutSessionView(day: nextWorkoutDay)
                    } label: {
                        ActionPill(title: "Start Today", icon: "play.fill")
                    }
                    .buttonStyle(.plain)
                } else if finishedTodaysProgramWorkout {
                    ActionPill(title: "Done today", icon: "checkmark.circle.fill")
                        .opacity(0.55)
                } else {
                    ActionPill(title: "Start Today", icon: "play.fill")
                        .opacity(0.45)
                }

                Button {
                    selectedTab = .progress
                } label: {
                    ActionPill(title: "Progress", icon: "chart.xyaxis.line")
                }
                .buttonStyle(.plain)

                Button {
                    showPRBoardSheet = true
                } label: {
                    ActionPill(title: "PR Board", icon: "trophy.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stepsCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.green.opacity(0.10))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.green)
                }

                            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Steps")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)

                if stepSync.isAuthorized {
                    Text("\(stepSync.stepCount.formatted(.number.grouping(.automatic))) / \(dailyStepGoal.formatted(.number.grouping(.automatic)))")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                    Text("\(stepGoalProgressPercent)% of daily goal")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(AppTheme.primaryBlue)
                } else {
                    Text("Enable Health access to sync Zepp steps")
                        .font(.system(.caption, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.mutedText)
                }
            }

            Spacer()

            Button("Refresh") {
                Task {
                    await stepSync.refreshTodaySteps()
                    await stepSync.refreshWeeklySteps()
                }
            }
            .font(.system(.caption, design: .default, weight: .semibold))
            .foregroundStyle(AppTheme.primaryBlue)
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

private struct DayCard: View {
    var day: WorkoutDay

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(day.isCompleted ? AppTheme.primaryBlue.opacity(0.12) : Color.clear)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                day.isCompleted ? AppTheme.primaryBlue.opacity(0.35) : AppTheme.cardBorder,
                                lineWidth: 1
                            )
                    )
                if day.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(AppTheme.primaryBlue)
                } else {
                    Text("\(day.dayIndex)")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                                Text("Day \(day.dayIndex)")
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                                Text(day.focus)
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(AppTheme.bodyText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

private struct StatTile: View {
    var title: String
    var value: String
    var icon: String
    var tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(value)
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
            }
            Spacer()
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

private struct HomeMetricTile<Footer: View>: View {
    var title: String
    var value: String
    var valueSuffix: String
    var icon: String
    var iconTint: Color
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconTint)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.titleText)
                    .monospacedDigit()
                if !valueSuffix.isEmpty {
                    Text(valueSuffix)
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedText)
                }
                Spacer()
            }

            footer
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

private struct HomeActionPill: View {
    var title: String
    var icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(.caption, design: .default, weight: .semibold))
        }
        .foregroundStyle(AppTheme.primaryBlue)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppTheme.subtleFill, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AppTheme.primaryBlue.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct ActionPill: View {
    var title: String
    var icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.system(.caption, design: .default, weight: .semibold))
        }
        .foregroundStyle(AppTheme.primaryBlue)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.clear)
        .overlay(
            Capsule()
                .strokeBorder(AppTheme.primaryBlue.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct BottomTabBar: View {
    @Binding var selectedTab: HomeTab

    var body: some View {
        HStack {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                        Text(tab.title)
                            .font(.system(size: 9, weight: .medium, design: .default))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(selectedTab == tab ? AppTheme.primaryBlue : AppTheme.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(AppTheme.cardBackground.opacity(AppTheme.isDarkModeEnabled ? 0.72 : 0.9))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

private struct PRBoardView: View {
    var records: [PersonalRecord]
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if records.isEmpty {
                    EmptyStateCard(
                        title: "No PRs yet",
                        subtitle: "Complete strength sets to start building your PR board.",
                        icon: "trophy"
                    )
                } else {
                    ForEach(records, id: \.persistentModelID) { record in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.yellow.opacity(0.12))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.yellow)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.exerciseName)
                                    .font(.system(.body, design: .default, weight: .semibold))
                                    .foregroundStyle(AppTheme.titleText)
                                Text("\(WeightDisplay.formatted(record.maxWeight, unit: weightUnit)) × \(record.repsAtMaxWeight) reps")
                                    .font(.system(.subheadline, design: .default, weight: .regular))
                                    .foregroundStyle(AppTheme.bodyText)
                                Text(record.achievedAt, style: .date)
                                    .font(.system(.caption, design: .default, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
                    }
                }
            }
        }
    }

}

private struct ProgressTabView: View {
    var completionPercent: Int
    var weeklyGoalPercent: Int
    var stepGoalPercent: Int
    var completedDayCount: Int
    var totalDays: Int
    var totalExercises: Int
    var stepCount: Int
    var personalRecordCount: Int
    var weeklyWorkoutGoal: Int
    var dailyStepGoal: Int
    var weeklyStepPoints: [StepPoint]
    var completedWorkoutPoints: [CompletionPoint]
    var completedSessions: [CompletedWorkoutSession]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                weeklyReviewCard
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ProgressMetricTile(
                        title: "Weekly Progress",
                        value: "+\(completionPercent)%",
                        subtitle: "Vs last week",
                        icon: "chart.line.uptrend.xyaxis",
                        accent: AppTheme.primaryBlue
                    )
                    ProgressMetricTile(
                        title: "Sessions",
                        value: "\(completedDayCount)",
                        subtitle: "This week",
                        icon: "dumbbell",
                        accent: AppTheme.primaryBlue
                    )
                    ProgressMetricTile(
                        title: "Step Goal",
                        value: "\(dailyStepGoal.formatted(.number.grouping(.automatic)))",
                        subtitle: "\(stepCount.formatted(.number.grouping(.automatic))) today",
                        icon: "shoeprints.fill",
                        accent: AppTheme.primaryBlue
                    )
                    ProgressMetricTile(
                        title: "PR Count",
                        value: "\(personalRecordCount)",
                        subtitle: "This month",
                        icon: "trophy.fill",
                        accent: AppTheme.primaryBlue
                    )
                }

                trendCard
            }
        }
    }

    private var weeklyReviewCard: some View {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let mondayOffset = (weekday + 5) % 7
        let weekStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -mondayOffset, to: now) ?? now)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        let thisWeek = completedSessions.filter { $0.completedAt >= weekStart && $0.completedAt < nextWeek }

        let sessionCount = thisWeek.count
        var totalVolume = 0.0
        var volumeByExercise: [String: Double] = [:]
        for session in thisWeek {
            for exercise in session.exerciseSnapshots {
                let exerciseVolume = exercise.setSnapshots
                    .filter(\.isCompleted)
                    .reduce(0.0) { $0 + (Double($1.reps) * $1.weight) }
                totalVolume += exerciseVolume
                volumeByExercise[exercise.name, default: 0] += exerciseVolume
            }
        }
        let topExercises = volumeByExercise
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
        let goalHit = weeklyWorkoutGoal > 0 && sessionCount >= weeklyWorkoutGoal

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weekly Review")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Text(goalHit ? "Goal hit" : "\(sessionCount)/\(max(1, weeklyWorkoutGoal))")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(goalHit ? .green : AppTheme.primaryBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((goalHit ? Color.green : AppTheme.primaryBlue).opacity(0.12), in: Capsule())
            }

            HStack(spacing: 12) {
                reviewStat(title: "Sessions", value: "\(sessionCount)")
                reviewStat(title: "Volume", value: WeightDisplay.formatted(totalVolume, unit: .lb))
                reviewStat(title: "PRs", value: "See PR Board")
            }

            if topExercises.isEmpty {
                Text("No completed sessions this week yet. Finish one day to populate your review.")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
            } else {
                Text("Top lifts this week: \(topExercises.joined(separator: " • "))")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func reviewStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.titleText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Steps — Last 7 Days")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                let avg = weeklyStepPoints.isEmpty ? 0 : Int(Double(weeklyStepPoints.reduce(0) { $0 + $1.steps }) / Double(weeklyStepPoints.count))
                Text("Avg \(avg.formatted(.number.grouping(.automatic)))")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }

            Chart {
                ForEach(weeklyStepPoints) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Steps", point.steps)
                    )
                    .foregroundStyle(AppTheme.primaryBlue.opacity(AppTheme.isDarkModeEnabled ? 0.85 : 0.35))
                }
                ForEach(completedWorkoutPoints) { point in
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Sessions", point.completedSessions * 2000)
                    )
                    .foregroundStyle(Color.orange.opacity(0.85))
                    .lineStyle(.init(lineWidth: 2))
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

private struct MoreTabView: View {
    var completedSessions: [CompletedWorkoutSession]
    @ObservedObject var stepSync: StepCountManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink {
                    CharacterSheetView()
                        .padding(.top, 10)
                } label: {
                    moreCard(
                        title: "Character",
                        subtitle: "RPG build, forms, and stat allocation",
                        icon: "person.crop.rectangle.stack.fill"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HistoryTabView(completedSessions: completedSessions)
                        .padding(.top, 10)
                } label: {
                    moreCard(
                        title: "Workout History",
                        subtitle: "Browse your completed sessions timeline",
                        icon: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SettingsTabView(stepSync: stepSync)
                        .padding(.top, 10)
                } label: {
                    moreCard(
                        title: "Settings",
                        subtitle: "Backup, appearance, goals, and app preferences",
                        icon: "gearshape.fill"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func moreCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.primaryBlue.opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Text(subtitle)
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

private struct ProgressMetricTile: View {
    var title: String
    var value: String
    var subtitle: String
    var icon: String
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
            }
            Text(title)
                .font(.system(.caption, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.titleText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(.caption, design: .default, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

private struct CompletionCalendarSheet: View {
    var workoutDays: [WorkoutDay]
    @State private var selectedDate = Date()
    @State private var visibleMonth = Date()

    private var completedSessionDates: Set<Date> {
        let calendar = Calendar.current
        var dates = Set<Date>()
        for day in workoutDays where day.isCompleted {
            let anchor = day.sessionCompletedAt ?? day.sessionStartedAt ?? Date()
            dates.insert(calendar.startOfDay(for: anchor))
        }
        return dates
    }

    private var selectedDaySessions: [WorkoutDay] {
        let calendar = Calendar.current
        let selectedStart = calendar.startOfDay(for: selectedDate)
        return workoutDays
            .filter { day in
                guard day.isCompleted else { return false }
                let anchor = day.sessionCompletedAt ?? day.sessionStartedAt
                guard let anchor else { return false }
                return calendar.isDate(anchor, inSameDayAs: selectedStart)
            }
            .sorted { historyAnchor($0) > historyAnchor($1) }
    }

    private func historyAnchor(_ day: WorkoutDay) -> Date {
        day.sessionCompletedAt ?? day.sessionStartedAt ?? .distantPast
    }

    private var selectedDateIsCompleted: Bool {
        completedSessionDates.contains(Calendar.current.startOfDay(for: selectedDate))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tap a date to view completed sessions. Dates with a filled circle are completed workout days.")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(AppTheme.bodyText)

                MonthCompletionCalendarView(
                    visibleMonth: $visibleMonth,
                    selectedDate: $selectedDate,
                    completedSessionDates: completedSessionDates
                )

                HStack {
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.headline, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.titleText)
                    Spacer()
                    Label(
                        selectedDateIsCompleted ? "Completed" : "No session",
                        systemImage: selectedDateIsCompleted ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(selectedDateIsCompleted ? .green : AppTheme.mutedText)
                }

                if selectedDaySessions.isEmpty {
                    EmptyStateCard(
                        title: "No workouts on this date",
                        subtitle: "Complete a day and it will be marked with a circle.",
                        icon: "calendar.badge.exclamationmark"
                    )
                } else {
                    ForEach(selectedDaySessions, id: \.persistentModelID) { day in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.green)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Day \(day.dayIndex) • \(day.focus)")
                                    .font(.system(.body, design: .default, weight: .semibold))
                                    .foregroundStyle(AppTheme.titleText)
                                if let completedAt = day.sessionCompletedAt {
                                    Text(completedAt.formatted(date: .omitted, time: .shortened))
                                        .font(.system(.caption, design: .default, weight: .medium))
                                        .foregroundStyle(AppTheme.mutedText)
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .minimalCard(cornerRadius: 14)
                    }
                }
            }
        }
        .onAppear {
            visibleMonth = selectedDate
        }
    }
}

private struct MonthCompletionCalendarView: View {
    @Binding var visibleMonth: Date
    @Binding var selectedDate: Date
    var completedSessionDates: Set<Date>

    private let calendar = Calendar.current
    private let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.subtleFill, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()
                Text(monthTitle(for: visibleMonth))
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.subtleFill, in: Circle())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { label in
                    Text(label)
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(dayCells(for: visibleMonth), id: \.id) { cell in
                    if let date = cell.date {
                        let start = calendar.startOfDay(for: date)
                        let isSelected = calendar.isDate(start, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(start)
                        let isCompleted = completedSessionDates.contains(start)

                        Button {
                            selectedDate = start
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(cell.dayNumber)")
                                    .font(.system(.subheadline, design: .default, weight: .semibold))
                                    .foregroundStyle(isSelected ? Color.black.opacity(0.85) : AppTheme.titleText)
                                    .frame(width: 30, height: 24)

                                Circle()
                                    .fill(isCompleted ? Color.green : Color.clear)
                                    .frame(width: 6, height: 6)
                                    .frame(height: 8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? AppTheme.primaryBlue : (isToday ? AppTheme.subtleFill : Color.clear))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        isToday && !isSelected ? AppTheme.primaryBlue.opacity(0.5) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("Completed day")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
                Spacer()
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func monthTitle(for date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private func changeMonth(by delta: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: delta, to: visibleMonth) ?? visibleMonth
    }

    private func dayCells(for monthDate: Date) -> [CalendarDayCell] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmpty = (firstWeekday + 5) % 7 // convert to Monday-first

        var cells: [CalendarDayCell] = Array(repeating: CalendarDayCell(date: nil, dayNumber: 0), count: leadingEmpty)
        for day in 1...daysInMonth {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)
            cells.append(CalendarDayCell(date: date, dayNumber: day))
        }
        while cells.count % 7 != 0 {
            cells.append(CalendarDayCell(date: nil, dayNumber: 0))
        }
        return cells
    }
}

private struct CalendarDayCell: Identifiable {
    let id = UUID()
    let date: Date?
    let dayNumber: Int
}

private struct HistoryTabView: View {
    var completedSessions: [CompletedWorkoutSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if completedSessions.isEmpty {
                    EmptyStateCard(
                        title: "No sessions yet",
                        subtitle: "Complete a workout day and it will be permanently saved here.",
                        icon: "clock.badge.checkmark"
                    )
                } else {
                    ForEach(completedSessions, id: \.persistentModelID) { session in
                        NavigationLink {
                            SessionHistoryDetailView(session: session)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(Color.green.opacity(0.9), lineWidth: 2)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.green.opacity(0.9))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Day \(session.sourceDayIndex) • \(session.dayFocus)")
                                        .font(.system(.body, design: .default, weight: .semibold))
                                        .foregroundStyle(AppTheme.titleText)
                                    HStack(spacing: 10) {
                                        Label(session.completedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                        Label(session.completedAt.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                                    }
                                    .font(.system(.caption, design: .default, weight: .medium))
                                    .foregroundStyle(AppTheme.primaryBlue)
                                    .labelStyle(.titleAndIcon)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.mutedText.opacity(0.8))
                            }
                            .padding(14)
                            .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct SessionHistoryDetailView: View {
    @Bindable var session: CompletedWorkoutSession
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    private var sortedExercises: [CompletedExerciseSnapshot] {
        session.exerciseSnapshots.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day \(session.sourceDayIndex)")
                            .font(.system(size: 22, weight: .semibold, design: .default))
                        Text(session.dayFocus)
                            .font(.system(.subheadline, design: .default, weight: .medium))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    Spacer()
                    Text(session.completedAt, style: .date)
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                }

                ForEach(sortedExercises, id: \.persistentModelID) { exercise in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text(exercise.name)
                                .font(.system(.body, design: .default, weight: .semibold))
                                .foregroundStyle(AppTheme.titleText)
                            Spacer()
                            if exercise.kind == .strength {
                                Text(exercise.targetSetsReps)
                                    .font(.system(.caption, design: .default, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                        }

                        if exercise.kind == .cardio {
                            Text(exercise.targetSetsReps)
                                .font(.system(.subheadline, design: .default, weight: .regular))
                                .foregroundStyle(AppTheme.bodyText)
                            if !exercise.cardioDurationNote.isEmpty {
                                Text(exercise.cardioDurationNote)
                                    .font(.system(.caption, design: .default, weight: .medium))
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                            Text(exercise.cardioCompleted ? "Completed" : "Not completed")
                                .font(.system(.caption, design: .default, weight: .semibold))
                                .foregroundStyle(exercise.cardioCompleted ? .green : AppTheme.mutedText)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(exercise.setSnapshots.sorted { $0.setIndex < $1.setIndex }, id: \.persistentModelID) { log in
                                    HStack {
                                        Text("Set \(log.setIndex)")
                                            .font(.system(.caption, design: .default, weight: .semibold))
                                            .foregroundStyle(AppTheme.mutedText)
                                            .frame(width: 44, alignment: .leading)
                                        Text("\(log.reps) reps")
                                            .font(.system(.subheadline, design: .default, weight: .medium))
                                            .foregroundStyle(AppTheme.titleText)
                                        Spacer()
                                        Text(WeightDisplay.formatted(log.weight, unit: weightUnit))
                                            .font(.system(.subheadline, design: .default, weight: .semibold))
                                            .foregroundStyle(AppTheme.titleText)
                                            .monospacedDigit()
                                        if log.isCompleted {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.green.opacity(0.9))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimalCard(cornerRadius: 14)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsTabView: View {
    @ObservedObject var stepSync: StepCountManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("dailyStepGoal") private var dailyStepGoal = 10000
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal = 5
    @AppStorage("programWeekStartsOnWeekday") private var programWeekStartsOnWeekday = 2
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue
    @AppStorage("openAIMealAPIKey") private var openAIMealAPIKey = ""
    @AppStorage("lastBackupAt") private var lastBackupAt = 0.0
    @State private var backupDocument = LocalBackupJSONDocument(data: Data())
    @State private var csvTemplateDocument = CSVTemplateDocument(text: CSVWorkoutImportService.templateCSV())
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showCSVImporter = false
    @State private var showCSVTemplateExporter = false
    @State private var backupStatus = ""
    @State private var showBackupStatus = false

    private var lastBackupDate: Date? {
        lastBackupAt > 0 ? Date(timeIntervalSince1970: lastBackupAt) : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SettingsSectionCard(title: "Goals", icon: "target") {
                    SettingsGoalRow(
                        icon: "shoeprints.fill",
                        title: "Daily Steps",
                        valueText: dailyStepGoal.formatted(.number.grouping(.automatic)),
                        onDecrement: {
                            dailyStepGoal = max(2000, dailyStepGoal - 500)
                        },
                        onIncrement: {
                            dailyStepGoal = min(30000, dailyStepGoal + 500)
                        }
                    )

                    Divider().overlay(AppTheme.cardBorder)

                    SettingsGoalRow(
                        icon: "dumbbell.fill",
                        title: "Weekly Workouts",
                        valueText: "\(weeklyWorkoutGoal)",
                        onDecrement: {
                            weeklyWorkoutGoal = max(1, weeklyWorkoutGoal - 1)
                        },
                        onIncrement: {
                            weeklyWorkoutGoal = min(7, weeklyWorkoutGoal + 1)
                        }
                    )
                }

                SettingsSectionCard(title: "Program", icon: "calendar") {
                    Text("Match Today's Plan to your calendar: which day of the week is Day 1 of your program? Usually Monday.")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                    Picker("Day 1 of program", selection: $programWeekStartsOnWeekday) {
                        Text("Monday (typical)").tag(2)
                        Text("Sunday").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                SettingsSectionCard(title: "Units", icon: "scalemass") {
                    Picker("Weight Unit", selection: $weightUnitRaw) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                SettingsSectionCard(title: "Meal photos (AI)", icon: "camera.metering.multispot") {
                    Text("Log meal → Photo defaults to free on-device matching. If you choose OpenAI there, this key is used. Stored on this device only.")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                    SecureField("OpenAI API key (sk-…)", text: $openAIMealAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Text("Create or copy a secret key at platform.openai.com/api-keys — billing applies per OpenAI’s pricing.")
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                }

                SettingsSectionCard(title: "Health Sync", icon: "heart") {
                    Text("Sync your workouts, steps, and health data with Apple Health to keep everything up to date across your devices.")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                    Button {
                        Task { await stepSync.requestAccessAndRefresh() }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Refresh", systemImage: "arrow.clockwise")
                            Spacer()
                        }
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black.opacity(AppTheme.isDarkModeEnabled ? 0.85 : 0.74))
                    .background(AppTheme.primaryBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                SettingsSectionCard(title: "Backup", icon: "arrow.clockwise.icloud") {
                    Text("Export or import your full workout data as JSON.")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                    if let lastBackupDate {
                        Text("Last backup: \(lastBackupDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(.caption, design: .default, weight: .medium))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    HStack(spacing: 10) {
                        Button {
                            do {
                                let data = try LocalBackupService.exportBackup(from: modelContext)
                                backupDocument = LocalBackupJSONDocument(data: data)
                                lastBackupAt = Date().timeIntervalSince1970
                                showExporter = true
                            } catch {
                                backupStatus = "Export failed: \(error.localizedDescription)"
                                showBackupStatus = true
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Export", systemImage: "square.and.arrow.up")
                                Spacer()
                            }
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.primaryBlue)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                        )

                        Button {
                            showImporter = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Import", systemImage: "square.and.arrow.down")
                                Spacer()
                            }
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.primaryBlue)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                        )
                    }

                    Button {
                        showCSVImporter = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Import CSV (Google Sheets)", systemImage: "tablecells.badge.ellipsis")
                            Spacer()
                        }
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.primaryBlue)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                    )

                    Button {
                        csvTemplateDocument = CSVTemplateDocument(text: CSVWorkoutImportService.templateCSV())
                        showCSVTemplateExporter = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Export CSV Template", systemImage: "square.and.arrow.up.on.square")
                            Spacer()
                        }
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.primaryBlue)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                    )
                }
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "workout-backup-\(Date().formatted(date: .numeric, time: .omitted))"
        ) { _ in }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    let data = try readImportedFileData(from: url)
                    try LocalBackupService.importBackup(data, into: modelContext)
                    lastBackupAt = Date().timeIntervalSince1970
                    backupStatus = "Backup imported successfully."
                } catch {
                    backupStatus = "Import failed: \(error.localizedDescription)"
                }
                showBackupStatus = true
            case .failure(let error):
                backupStatus = "Import cancelled: \(error.localizedDescription)"
                showBackupStatus = true
            }
        }
        .fileImporter(
            isPresented: $showCSVImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    let data = try readImportedFileData(from: url)
                    let summary = try CSVWorkoutImportService.importCSV(
                        data,
                        sourceName: url.lastPathComponent,
                        into: modelContext
                    )
                    backupStatus = "Imported \(summary.rowsImported) rows into \(summary.daysCreated) sessions and \(summary.exercisesCreated) exercises."
                } catch {
                    backupStatus = "CSV import failed: \(error.localizedDescription)"
                }
                showBackupStatus = true
            case .failure(let error):
                backupStatus = "CSV import cancelled: \(error.localizedDescription)"
                showBackupStatus = true
            }
        }
        .fileExporter(
            isPresented: $showCSVTemplateExporter,
            document: csvTemplateDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "workout-import-template"
        ) { _ in }
        .alert("Backup Status", isPresented: $showBackupStatus) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(backupStatus)
        }
    }

    private func readImportedFileData(from url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        return try Data(contentsOf: url)
    }
}

private struct SettingsGoalRow: View {
    var icon: String
    var title: String
    var valueText: String
    var onDecrement: () -> Void
    var onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
                Text(valueText)
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
            }

            Spacer()

            HStack(spacing: 10) {
                SettingsMiniButton(systemName: "minus") {
                    onDecrement()
                }
                Text(valueText)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                    .frame(minWidth: 60)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                SettingsMiniButton(systemName: "plus") {
                    onIncrement()
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SettingsMiniButton: View {
    var systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.titleText.opacity(0.9))
                .frame(width: 36, height: 32)
                .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSectionCard<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryBlue)
                Text(title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
            }

            content
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

private struct EmptyStateCard: View {
    var title: String
    var subtitle: String
    var icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AppTheme.primaryBlue)
            Text(title)
                .font(.system(.body, design: .default, weight: .semibold))
            Text(subtitle)
                .font(.system(.subheadline, design: .default, weight: .regular))
                .foregroundStyle(AppTheme.bodyText)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }
}

struct StepPoint: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
}

private struct CompletionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let completedSessions: Int
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let label: String
    let dayNumber: Int
    let isToday: Bool
}

private struct OnboardingItem: Identifiable {
    let id = UUID()
    let title: String
    let isDone: Bool
}

private enum HomeTab: CaseIterable {
    case home
    case workouts
    case nutrition
    case progress
    case more

    var title: String {
        switch self {
        case .home: return "Home"
        case .workouts: return "Train"
        case .nutrition: return "Meals"
        case .progress: return "Progress"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .workouts: return "dumbbell.fill"
        case .nutrition: return "fork.knife"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

private extension WorkoutDay {
    var isCompleted: Bool {
        if sessionCompletedAt != nil { return true }
        guard !exercises.isEmpty else { return false }
        return exercises.allSatisfy { exercise in
            if exercise.kind == .cardio {
                return exercise.cardioCompleted
            }
            guard !exercise.setLogs.isEmpty else { return false }
            return exercise.setLogs.allSatisfy(\.isCompleted)
        }
    }
}

@MainActor
final class StepCountManager: ObservableObject {
    @Published var stepCount: Int = 0
    @Published var isAuthorized = false
    @Published var weeklyStepPoints: [StepPoint] = []

    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)

    func requestAccessAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable(), let stepType else {
            isAuthorized = false
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            isAuthorized = true
            await refreshTodaySteps()
            await refreshWeeklySteps()
        } catch {
            isAuthorized = false
        }
    }

    func refreshTodaySteps() async {
        guard isAuthorized, let stepType else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            guard let self else { return }
            let steps = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
            DispatchQueue.main.async {
                self.stepCount = max(0, steps)
            }
        }
        healthStore.execute(query)
    }

    func refreshWeeklySteps() async {
        guard isAuthorized, let stepType else { return }
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate)) ?? endDate
        let anchorDate = calendar.startOfDay(for: endDate)
        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, collection, _ in
            guard let self, let collection else { return }
            var points: [StepPoint] = []
            collection.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let steps = Int(stats.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                points.append(StepPoint(date: stats.startDate, steps: max(0, steps)))
            }
            DispatchQueue.main.async {
                self.weeklyStepPoints = points
            }
        }
        healthStore.execute(query)
    }
}

struct LocalBackupJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct LocalBackupPayload: Codable {
    var exportedAt: Date
    var programs: [LocalProgramDTO]
    var personalRecords: [LocalPersonalRecordDTO]
}

private struct LocalProgramDTO: Codable {
    var name: String
    var createdAt: Date
    var days: [LocalWorkoutDayDTO]
}

private struct LocalWorkoutDayDTO: Codable {
    var dayIndex: Int
    var focus: String
    var sessionStartedAt: Date?
    var sessionCompletedAt: Date?
    var isSessionActive: Bool
    var completionCount: Int
    var exercises: [LocalExerciseDTO]
}

private struct LocalExerciseDTO: Codable {
    var name: String
    var targetSetsReps: String
    var kindRaw: String
    var sortOrder: Int
    var cardioCompleted: Bool
    var cardioDurationNote: String
    var setLogs: [LocalSetLogDTO]
}

private struct LocalSetLogDTO: Codable {
    var setIndex: Int
    var reps: Int
    var weight: Double
    var isCompleted: Bool
}

private struct LocalPersonalRecordDTO: Codable {
    var exerciseName: String
    var maxWeight: Double
    var repsAtMaxWeight: Int
    var achievedAt: Date
}

private enum LocalBackupService {
    static func exportBackup(from context: ModelContext) throws -> Data {
        let programs = try context.fetch(FetchDescriptor<WorkoutProgram>())
        let records = try context.fetch(FetchDescriptor<PersonalRecord>())

        let payload = LocalBackupPayload(
            exportedAt: .now,
            programs: programs.map(programDTO),
            personalRecords: records.map {
                LocalPersonalRecordDTO(
                    exerciseName: $0.exerciseName,
                    maxWeight: $0.maxWeight,
                    repsAtMaxWeight: $0.repsAtMaxWeight,
                    achievedAt: $0.achievedAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func importBackup(_ data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(LocalBackupPayload.self, from: data)
        guard !payload.programs.isEmpty || !payload.personalRecords.isEmpty else {
            throw NSError(
                domain: "Backup",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Backup file has no workout data."]
            )
        }

        try context.fetch(FetchDescriptor<WorkoutProgram>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PersonalRecord>()).forEach { context.delete($0) }

        for program in payload.programs {
            let modelProgram = WorkoutProgram(name: program.name, createdAt: program.createdAt)
            modelProgram.days = program.days.map { dayDTO in
                let day = WorkoutDay(
                    dayIndex: dayDTO.dayIndex,
                    focus: dayDTO.focus,
                    sessionStartedAt: dayDTO.sessionStartedAt,
                    sessionCompletedAt: dayDTO.sessionCompletedAt,
                    isSessionActive: dayDTO.isSessionActive,
                    completionCount: dayDTO.completionCount
                )
                day.exercises = dayDTO.exercises.map { exDTO in
                    let exercise = Exercise(
                        name: exDTO.name,
                        targetSetsReps: exDTO.targetSetsReps,
                        kind: ExerciseKind(rawValue: exDTO.kindRaw) ?? .strength,
                        sortOrder: exDTO.sortOrder,
                        cardioCompleted: exDTO.cardioCompleted,
                        cardioDurationNote: exDTO.cardioDurationNote,
                        setLogs: exDTO.setLogs.map {
                            SetLog(setIndex: $0.setIndex, reps: $0.reps, weight: $0.weight, isCompleted: $0.isCompleted)
                        }
                    )
                    exercise.workoutDay = day
                    exercise.setLogs.forEach { $0.exercise = exercise }
                    return exercise
                }
                day.program = modelProgram
                return day
            }
            context.insert(modelProgram)
        }

        for record in payload.personalRecords {
            context.insert(
                PersonalRecord(
                    exerciseName: record.exerciseName,
                    maxWeight: record.maxWeight,
                    repsAtMaxWeight: record.repsAtMaxWeight,
                    achievedAt: record.achievedAt
                )
            )
        }
        try context.save()
    }

    private static func programDTO(_ program: WorkoutProgram) -> LocalProgramDTO {
        LocalProgramDTO(
            name: program.name,
            createdAt: program.createdAt,
            days: program.days.map { day in
                LocalWorkoutDayDTO(
                    dayIndex: day.dayIndex,
                    focus: day.focus,
                    sessionStartedAt: day.sessionStartedAt,
                    sessionCompletedAt: day.sessionCompletedAt,
                    isSessionActive: day.isSessionActive,
                    completionCount: day.completionCount,
                    exercises: day.exercises.map { exercise in
                        LocalExerciseDTO(
                            name: exercise.name,
                            targetSetsReps: exercise.targetSetsReps,
                            kindRaw: exercise.kindRaw,
                            sortOrder: exercise.sortOrder,
                            cardioCompleted: exercise.cardioCompleted,
                            cardioDurationNote: exercise.cardioDurationNote,
                            setLogs: exercise.setLogs.map {
                                LocalSetLogDTO(setIndex: $0.setIndex, reps: $0.reps, weight: $0.weight, isCompleted: $0.isCompleted)
                            }
                        )
                    }
                )
            }
        )
    }
}

private struct CSVImportSummary {
    var rowsImported: Int
    var daysCreated: Int
    var exercisesCreated: Int
}

private enum CSVWorkoutImportService {
    static func templateCSV() -> String {
        """
        date,day,focus,exercise,kind,set,reps,weight,completed,cardioCompleted,target,notes
        2026-05-05,2,Upper Body,Incline Dumbbell Press,strength,1,10,55,true,,3x10,
        2026-05-05,2,Upper Body,Incline Dumbbell Press,strength,2,9,55,true,,3x10,
        2026-05-05,2,Upper Body,Incline Dumbbell Press,strength,3,8,55,true,,3x10,
        2026-05-05,2,Upper Body,Lat Pulldown,strength,1,12,120,true,,3x12,
        2026-05-05,2,Upper Body,Lat Pulldown,strength,2,11,120,true,,3x12,
        2026-05-05,2,Upper Body,Treadmill Walk,cardio,,,,,true,30 min,Incline 8 speed 3.0
        """
    }

    static func importCSV(_ data: Data, sourceName: String? = nil, into context: ModelContext, currentProgramWeek: Int = 6) throws -> CSVImportSummary {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw NSError(
                domain: "CSVImport",
                code: 2001,
                userInfo: [NSLocalizedDescriptionKey: "File must be UTF-8 text."]
            )
        }

        let rawLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        guard rawLines.count >= 2 else {
            throw NSError(
                domain: "CSVImport",
                code: 2002,
                userInfo: [NSLocalizedDescriptionKey: "CSV needs a header row and at least one data row."]
            )
        }

        let headerColumns = parseCSVLine(rawLines[0]).map(normalizeHeader)
        guard !headerColumns.isEmpty else {
            throw NSError(
                domain: "CSVImport",
                code: 2003,
                userInfo: [NSLocalizedDescriptionKey: "Could not read CSV headers."]
            )
        }

        let dateIndex = index(forAnyOf: ["date", "sessiondate", "completedat", "workoutdate"], in: headerColumns)
        let exerciseIndex = index(forAnyOf: ["exercise", "exercisename", "name"], in: headerColumns)
        guard let exerciseIndex else {
            throw NSError(
                domain: "CSVImport",
                code: 2004,
                userInfo: [NSLocalizedDescriptionKey: "CSV needs an 'exercise' column."]
            )
        }

        let dayIndexIndex = index(forAnyOf: ["dayindex", "day", "weekday"], in: headerColumns)
        let focusIndex = index(forAnyOf: ["focus", "musclegroup", "dayfocus"], in: headerColumns)
        let kindIndex = index(forAnyOf: ["kind", "type"], in: headerColumns)
        let targetIndex = index(forAnyOf: ["targetsetsreps", "target", "plan"], in: headerColumns)
        let setIndexIndex = index(forAnyOf: ["setindex", "set", "setnumber"], in: headerColumns)
        let repsIndex = index(forAnyOf: ["reps", "rep"], in: headerColumns)
        let weightIndex = index(forAnyOf: ["weight", "lbs", "lb", "kg"], in: headerColumns)
        let completedIndex = index(forAnyOf: ["completed", "done", "iscompleted"], in: headerColumns)
        let cardioCompletedIndex = index(forAnyOf: ["cardiocompleted", "cardiodone"], in: headerColumns)
        let notesIndex = index(forAnyOf: ["notes", "cardionote", "comment"], in: headerColumns)
        let setColumnIndices: [Int] = headerColumns.enumerated()
            .filter { entry in
                let key = entry.element
                return key.hasPrefix("set") && key != "set" && key != "setindex" && key != "setnumber"
            }
            .map(\.offset)
            .sorted()

        let legacyWeekNumber = weekNumber(from: sourceName)

        let importedProgram = WorkoutProgram(name: "Imported History", createdAt: .now)
        context.insert(importedProgram)

        var dayMap: [String: WorkoutDay] = [:]
        var exerciseMap: [String: Exercise] = [:]
        var rowsImported = 0

        for line in rawLines.dropFirst() {
            let values = parseCSVLine(line)
            if values.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }

            let dateText = dateIndex.map { value(at: $0, in: values) } ?? ""
            let exerciseName = value(at: exerciseIndex, in: values)
            guard !exerciseName.isEmpty else { continue }
            let parsedDate: Date? = {
                if let explicit = parseDate(dateText) {
                    return explicit
                }
                guard let dayIndexIndex else { return nil }
                let dayForLegacy = Int(value(at: dayIndexIndex, in: values).filter(\.isNumber)) ?? 0
                guard (1...7).contains(dayForLegacy) else { return nil }
                let weekForLegacy = legacyWeekNumber ?? currentProgramWeek
                return synthesizedDateForLegacy(dayIndex: dayForLegacy, weekNumber: weekForLegacy, currentProgramWeek: currentProgramWeek)
            }()
            guard let parsedDate else { continue }

            let dayIndexValue: Int = {
                if let dayIndexIndex {
                    let parsed = Int(value(at: dayIndexIndex, in: values).filter(\.isNumber)) ?? 0
                    if (1...7).contains(parsed) { return parsed }
                }
                return mondayBasedIndex(for: parsedDate)
            }()

            let focusValue = {
                if let focusIndex {
                    let txt = value(at: focusIndex, in: values)
                    return txt.isEmpty ? "Imported Session" : txt
                }
                return "Imported Session"
            }()

            let dayKey = "\(Calendar.current.startOfDay(for: parsedDate).timeIntervalSince1970)-\(dayIndexValue)-\(focusValue)"
            let day: WorkoutDay
            if let existing = dayMap[dayKey] {
                day = existing
            } else {
                day = WorkoutDay(
                    dayIndex: dayIndexValue,
                    focus: focusValue,
                    sessionStartedAt: parsedDate,
                    sessionCompletedAt: parsedDate,
                    isSessionActive: false,
                    completionCount: 1
                )
                day.program = importedProgram
                importedProgram.days.append(day)
                dayMap[dayKey] = day
            }

            let kind: ExerciseKind = {
                let kindText = kindIndex.map { value(at: $0, in: values).lowercased() } ?? ""
                if kindText.contains("cardio") { return .cardio }
                if exerciseName.lowercased().contains("cardio") { return .cardio }
                return .strength
            }()
            let target = targetIndex.map { value(at: $0, in: values) }.flatMap { $0.isEmpty ? nil : $0 } ?? "3x10"

            let exerciseKey = "\(dayKey)-\(exerciseName.lowercased())-\(kind.rawValue)"
            let exercise: Exercise
            if let existing = exerciseMap[exerciseKey] {
                exercise = existing
            } else {
                exercise = Exercise(
                    name: exerciseName,
                    targetSetsReps: target,
                    kind: kind,
                    sortOrder: day.exercises.count,
                    cardioCompleted: false,
                    cardioDurationNote: ""
                )
                exercise.workoutDay = day
                day.exercises.append(exercise)
                exerciseMap[exerciseKey] = exercise
            }

            if kind == .cardio {
                let completed = boolValue(
                    cardioCompletedIndex.map { value(at: $0, in: values) }
                    ?? completedIndex.map { value(at: $0, in: values) }
                    ?? "true"
                )
                exercise.cardioCompleted = completed
                if let notesIndex {
                    let note = value(at: notesIndex, in: values)
                    if !note.isEmpty { exercise.cardioDurationNote = note }
                }
            } else {
                if !setColumnIndices.isEmpty, setIndexIndex == nil, repsIndex == nil, weightIndex == nil {
                    var addedAtLeastOne = false
                    for (offset, setColumnIndex) in setColumnIndices.enumerated() {
                        let raw = value(at: setColumnIndex, in: values)
                        guard !raw.isEmpty else { continue }
                        guard let parsed = parseLegacySetCell(raw) else { continue }
                        let setLog = SetLog(
                            setIndex: offset + 1,
                            reps: parsed.reps,
                            weight: parsed.weight,
                            isCompleted: true
                        )
                        setLog.exercise = exercise
                        exercise.setLogs.append(setLog)
                        addedAtLeastOne = true
                    }
                    if !addedAtLeastOne {
                        let fallbackSet = SetLog(setIndex: 1, reps: 0, weight: 0, isCompleted: false)
                        fallbackSet.exercise = exercise
                        exercise.setLogs.append(fallbackSet)
                    }
                    rowsImported += 1
                    continue
                }

                let setIdx = setIndexIndex
                    .flatMap { Int(value(at: $0, in: values).filter(\.isNumber)) }
                    ?? (exercise.setLogs.count + 1)
                let reps = repsIndex
                    .flatMap { Int(value(at: $0, in: values).filter(\.isNumber)) }
                    ?? 0
                let weight = weightIndex
                    .flatMap { Double(value(at: $0, in: values).replacingOccurrences(of: ",", with: ".")) }
                    ?? 0
                let completed = completedIndex.map { boolValue(value(at: $0, in: values)) } ?? true

                let setLog = SetLog(setIndex: max(1, setIdx), reps: reps, weight: weight, isCompleted: completed)
                setLog.exercise = exercise
                exercise.setLogs.append(setLog)
            }

            rowsImported += 1
        }

        if rowsImported == 0 {
            context.delete(importedProgram)
            throw NSError(
                domain: "CSVImport",
                code: 2005,
                userInfo: [NSLocalizedDescriptionKey: "No valid rows found. Check date and exercise columns."]
            )
        }

        try context.save()
        return CSVImportSummary(
            rowsImported: rowsImported,
            daysCreated: dayMap.count,
            exercisesCreated: exerciseMap.count
        )
    }

    private static func value(at index: Int, in row: [String]) -> String {
        guard row.indices.contains(index) else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeHeader(_ input: String) -> String {
        input
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func index(forAnyOf keys: [String], in headers: [String]) -> Int? {
        for key in keys {
            if let idx = headers.firstIndex(of: key) { return idx }
        }
        return nil
    }

    private static func mondayBasedIndex(for date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        return ((weekday + 5) % 7) + 1
    }

    private static func boolValue(_ input: String) -> Bool {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["1", "true", "yes", "y", "done"].contains(value) { return true }
        if value.contains("✅") || value.contains("[✅") || value.contains("done") { return true }
        return false
    }

    private static func weekNumber(from sourceName: String?) -> Int? {
        guard let sourceName else { return nil }
        let pattern = "(?i)week\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(sourceName.startIndex..<sourceName.endIndex, in: sourceName)
        guard let match = regex.firstMatch(in: sourceName, options: [], range: range),
              match.numberOfRanges > 1,
              let weekRange = Range(match.range(at: 1), in: sourceName) else {
            return nil
        }
        return Int(sourceName[weekRange])
    }

    private static func synthesizedDateForLegacy(dayIndex: Int, weekNumber: Int, currentProgramWeek: Int) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7
        let startOfCurrentWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -mondayOffset, to: today) ?? today)
        let weekDelta = weekNumber - currentProgramWeek
        let dayDelta = max(0, dayIndex - 1)
        let totalDayOffset = (weekDelta * 7) + dayDelta
        return calendar.date(byAdding: .day, value: totalDayOffset, to: startOfCurrentWeek) ?? today
    }

    private static func parseLegacySetCell(_ raw: String) -> (reps: Int, weight: Double)? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let normalized = cleaned.replacingOccurrences(of: " ", with: "").lowercased()

        if normalized.contains("done") || normalized.contains("✅") {
            return nil
        }

        if let xIndex = normalized.firstIndex(of: "x") {
            let repsPart = String(normalized[..<xIndex]).filter { $0.isNumber }
            let weightPartRaw = String(normalized[normalized.index(after: xIndex)...])
            let weightPart = weightPartRaw.filter { $0.isNumber || $0 == "." }
            let reps = Int(repsPart) ?? 0
            let weight = Double(weightPart) ?? 0
            if reps == 0 && weight == 0 { return nil }
            return (reps, weight)
        }

        let repsOnly = Int(normalized.filter(\.isNumber)) ?? 0
        if repsOnly == 0 { return nil }
        return (repsOnly, 0)
    }

    private static func parseDate(_ raw: String) -> Date? {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: input) { return date }
        let isoBasic = ISO8601DateFormatter()
        if let date = isoBasic.date(from: input) { return date }

        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MM/dd/yy",
            "M/d/yy",
            "yyyy-MM-dd HH:mm",
            "MM/dd/yyyy HH:mm",
            "M/d/yyyy h:mm a"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: input) { return date }
        }
        return nil
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]
            if char == "\"" {
                let nextIndex = line.index(after: index)
                if inQuotes, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    current.append("\"")
                    index = line.index(after: nextIndex)
                    continue
                }
                inQuotes.toggle()
            } else if char == ",", !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
            index = line.index(after: index)
        }
        result.append(current)
        return result
    }
}

private struct CSVTemplateDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = String(data: data, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
