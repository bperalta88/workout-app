import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Bindable var day: WorkoutDay
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutDay.dayIndex) private var allWorkoutDays: [WorkoutDay]

    private var primaryWorkoutDays: [WorkoutDay] {
        PrimaryProgram.daysSorted(from: allWorkoutDays)
    }
    @AppStorage("weeklyWorkoutGoal") private var weeklyWorkoutGoal = 5
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue

    @State private var prHighlightSetIDs: Set<PersistentIdentifier> = []
    @State private var prCelebration: PRCelebrationState?
    @State private var isPRModalPresented = false
    @State private var sessionMessage: String?
    @State private var sessionSummary: SessionSummary?
    @State private var deferredMilestone: MilestoneCelebration?
    @State private var activeMilestone: MilestoneCelebration?
    @State private var isMilestoneModalPresented = false

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    private var allExercisesCompleted: Bool {
        let exercises = day.exercises
        guard !exercises.isEmpty else { return false }
        return exercises.allSatisfy { exercise in
            if exercise.kind == .cardio { return exercise.cardioCompleted }
            guard !exercise.setLogs.isEmpty else { return false }
            return exercise.setLogs.allSatisfy(\.isCompleted)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                sessionControlCard

                LazyVStack(spacing: 16) {
                ForEach(day.sortedExercises, id: \.persistentModelID) { exercise in
                    ExerciseSessionCard(
                        exercise: exercise,
                        workoutDay: day,
                        prHighlightSetIDs: prHighlightSetIDs,
                        onCardioCompletedChange: {
                            // Incomplete input should reopen a completed day.
                            if day.sessionCompletedAt != nil, !allExercisesCompleted {
                                day.sessionCompletedAt = nil
                            }
                            try? modelContext.save()
                        },
                        onSetCompletedChange: { setLog, completed in
                            handleSetCompletion(exercise: exercise, setLog: setLog, completed: completed)
                        },
                        onDeletedSetLog: { id in
                            prHighlightSetIDs.remove(id)
                        }
                    )
                }
            }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(AppTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Day \(day.dayIndex)")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                    Text(day.focus)
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(AppTheme.bodyText)
                }
            }
        }
        .overlay {
            if isPRModalPresented, let celebration = prCelebration {
                Group {
                    if celebration.isBossRaid {
                        BossDefeatedOverlay(
                            exerciseName: celebration.exerciseName,
                            weight: celebration.weight,
                            reps: celebration.reps,
                            previousPR: celebration.previousPR,
                            onDismiss: {
                                dismissPRModal()
                            }
                        )
                    } else {
                        PRCelebrationOverlay(
                            exerciseName: celebration.exerciseName,
                            weight: celebration.weight,
                            reps: celebration.reps,
                            previousPR: celebration.previousPR,
                            onDismiss: {
                                dismissPRModal()
                            }
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
            }
        }
        .overlay {
            if isMilestoneModalPresented, let celebration = activeMilestone {
                MilestoneCelebrationOverlay(celebration: celebration) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        isMilestoneModalPresented = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        activeMilestone = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
            }
        }
        .overlay(alignment: .top) {
            if let sessionMessage {
                Text(sessionMessage)
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.primaryBlue, in: Capsule())
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $sessionSummary) { summary in
            SessionSummarySheet(summary: summary)
        }
        .onChange(of: sessionSummary) { _, new in
            guard new == nil, let milestone = deferredMilestone else { return }
            deferredMilestone = nil
            activeMilestone = milestone
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                isMilestoneModalPresented = true
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isPRModalPresented)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isMilestoneModalPresented)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sessionMessage)
        .onChange(of: allExercisesCompleted) { _, allDone in
            guard allDone, day.sessionCompletedAt == nil else { return }
            completeDay()
        }
    }

    private func dismissPRModal() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            isPRModalPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            prCelebration = nil
        }
    }

    private func handleSetCompletion(exercise: Exercise, setLog: SetLog, completed: Bool) {
        if day.sessionCompletedAt != nil, !completed {
            day.sessionCompletedAt = nil
        }

        if exercise.kind == .strength, RPGProgressionEngine.isAccessoryMovement(exerciseName: exercise.name) {
            if completed {
                PlayerStats.awardAccessoryXP(reps: setLog.reps, in: modelContext)
            } else {
                PlayerStats.rollbackAccessoryXP(reps: setLog.reps, in: modelContext)
            }
        }

        guard exercise.kind == .strength, completed else {
            prHighlightSetIDs.remove(setLog.persistentModelID)
            try? modelContext.save()
            return
        }

        let wasBossRaid = PREngine.isBossRaidExercise(
            exercise: exercise,
            scheduledDay: day,
            in: modelContext
        )

        let result = PREngine.evaluateCompletionForPersonalRecord(
            exerciseName: exercise.name,
            weight: setLog.weight,
            reps: setLog.reps,
            in: modelContext
        )

        if result.isNewRecord {
            if wasBossRaid {
                PlayerStats.awardBossDefeatStatPoints(points: 3, in: modelContext)
            }
            try? modelContext.save()
            prHighlightSetIDs.insert(setLog.persistentModelID)
            prCelebration = PRCelebrationState(
                exerciseName: exercise.name,
                weight: result.currentWeight,
                reps: result.currentReps,
                previousPR: result.previousMaxWeight,
                isBossRaid: wasBossRaid
            )
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                isPRModalPresented = true
            }
            let autoDismiss = wasBossRaid ? 4.2 : 2.8
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismiss) {
                if isPRModalPresented {
                    dismissPRModal()
                }
            }
        } else {
            prHighlightSetIDs.remove(setLog.persistentModelID)
            try? modelContext.save()
        }
    }

    private var sessionControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isCompleted = day.sessionCompletedAt != nil
            let isInProgress = day.sessionCompletedAt == nil && day.isSessionActive

            HStack(spacing: 10) {
                Text(isCompleted ? "Completed" : (isInProgress ? "In Progress" : "Not Started"))
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(isCompleted ? .green : AppTheme.primaryBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.subtleFill))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isCompleted ? Color.green.opacity(0.55) : AppTheme.primaryBlue.opacity(0.55),
                                lineWidth: 1
                            )
                    )

                Spacer(minLength: 0)
            }

            Text(isCompleted
                 ? "Nice work — log saved."
                 : (isInProgress ? "Keep going. You’re building momentum." : "Ready when you are."))
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.bodyText)

            if isCompleted {
                VStack(spacing: 8) {
                    Button {
                        reopenDay()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reopen Day")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(SessionPrimaryButtonStyle(tint: .orange, isDisabled: false))

                    Button {
                        resetDayChecks()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Reset Checks")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(SessionSecondaryButtonStyle())
                }
            } else {
                VStack(spacing: 8) {
                    Button {
                        startSession()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(day.isSessionActive ? "Session Active" : "Start Session")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(SessionPrimaryButtonStyle(tint: AppTheme.primaryBlue, isDisabled: day.isSessionActive))

                    Button {
                        completeDay()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Complete Day")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!allExercisesCompleted)
                    .buttonStyle(SessionPrimaryButtonStyle(tint: .green, isDisabled: !allExercisesCompleted))
                }

                Button {
                    resetDayChecks()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset checks")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(SessionLinkButtonStyle())
                .padding(.top, 2)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private var statusText: String {
        if day.sessionCompletedAt != nil { return "Done" }
        if day.isSessionActive { return "In Progress" }
        return "Not Started"
    }

    private func startSession() {
        let prefilledValues = preloadFromMostRecentMatchingSession()
        if day.sessionStartedAt == nil { day.sessionStartedAt = .now }
        day.isSessionActive = true
        day.sessionCompletedAt = nil
        try? modelContext.save()
        if prefilledValues > 0 {
            showSessionMessage("Session started • loaded \(prefilledValues) previous values")
        } else {
            showSessionMessage("Session started")
        }
    }

    private func completeDay() {
        guard allExercisesCompleted else {
            showSessionMessage("Finish all exercises first")
            return
        }
        guard day.sessionCompletedAt == nil else { return }
        day.isSessionActive = false
        let previousCompleted = day.sessionCompletedAt
        let previousCount = day.completionCount
        let completedAt = Date()
        day.sessionCompletedAt = completedAt
        day.completionCount += 1
        let snapshot = makeCompletedSessionSnapshot(completedAt: completedAt)
        modelContext.insert(snapshot)
        do {
            try modelContext.save()
        } catch {
            day.sessionCompletedAt = previousCompleted
            day.completionCount = previousCount
            modelContext.delete(snapshot)
            showSessionMessage("Couldn’t save — try again")
            return
        }
        deferredMilestone = MilestoneEvaluator.evaluateAfterDayComplete(
            allWorkoutDays: primaryWorkoutDays,
            weeklyWorkoutGoal: weeklyWorkoutGoal
        )
        sessionSummary = buildSessionSummary()
        showSessionMessage("Day completed")
    }

    private func makeCompletedSessionSnapshot(completedAt: Date) -> CompletedWorkoutSession {
        let session = CompletedWorkoutSession(
            sourceDayIndex: day.dayIndex,
            dayFocus: day.focus,
            completedAt: completedAt,
            completionCountAtCapture: day.completionCount
        )

        let exerciseSnapshots = day.sortedExercises.map { exercise -> CompletedExerciseSnapshot in
            let setSnapshots = exercise.sortedSetLogs.map { set in
                CompletedSetSnapshot(
                    setIndex: set.setIndex,
                    reps: set.reps,
                    weight: set.weight,
                    isCompleted: set.isCompleted
                )
            }
            let exerciseSnapshot = CompletedExerciseSnapshot(
                name: exercise.name,
                targetSetsReps: exercise.targetSetsReps,
                kindRaw: exercise.kindRaw,
                cardioCompleted: exercise.cardioCompleted,
                cardioDurationNote: exercise.cardioDurationNote,
                sortOrder: exercise.sortOrder,
                setSnapshots: setSnapshots
            )
            exerciseSnapshot.session = session
            setSnapshots.forEach { $0.exercise = exerciseSnapshot }
            return exerciseSnapshot
        }
        session.exerciseSnapshots = exerciseSnapshots
        return session
    }

    private func reopenDay() {
        day.sessionCompletedAt = nil
        day.isSessionActive = true
        try? modelContext.save()
        showSessionMessage("Day reopened")
    }

    private func resetDayChecks() {
        for exercise in day.exercises {
            if exercise.kind == .cardio {
                exercise.cardioCompleted = false
            } else {
                for setLog in exercise.setLogs {
                    setLog.isCompleted = false
                }
            }
        }
        day.isSessionActive = false
        day.sessionCompletedAt = nil
        try? modelContext.save()
        showSessionMessage("Checks reset")
    }

    private func showSessionMessage(_ message: String) {
        sessionMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if sessionMessage == message {
                sessionMessage = nil
            }
        }
    }

    private func buildSessionSummary() -> SessionSummary {
        var completedSets = 0
        var totalReps = 0
        var totalVolume = 0.0
        var heaviestSetWeight = 0.0
        var heaviestSetReps = 0

        for exercise in day.exercises where exercise.kind == .strength {
            for set in exercise.setLogs where set.isCompleted {
                completedSets += 1
                totalReps += set.reps
                totalVolume += (Double(set.reps) * set.weight)
                if set.weight > heaviestSetWeight {
                    heaviestSetWeight = set.weight
                    heaviestSetReps = set.reps
                }
            }
        }

        let aiCoachRecap = generateAICoachRecap(
            completedSets: completedSets,
            totalReps: totalReps,
            totalVolume: totalVolume,
            heaviestSetWeight: heaviestSetWeight,
            heaviestSetReps: heaviestSetReps
        )

        return SessionSummary(
            dayTitle: "Day \(day.dayIndex) • \(day.focus)",
            completedSets: completedSets,
            totalReps: totalReps,
            totalVolume: totalVolume,
            completedAt: day.sessionCompletedAt ?? .now,
            aiCoachRecap: aiCoachRecap
        )
    }

    private func generateAICoachRecap(
        completedSets: Int,
        totalReps: Int,
        totalVolume: Double,
        heaviestSetWeight: Double,
        heaviestSetReps: Int
    ) -> String {
        let prHitsThisSession = prHighlightSetIDs.count

        let consistencyLine: String
        if completedSets >= 16 {
            consistencyLine = "Huge consistency today: \(completedSets) completed sets."
        } else if completedSets >= 10 {
            consistencyLine = "Solid work rate: \(completedSets) sets completed."
        } else {
            consistencyLine = "Good session completed. Keep stacking days."
        }

        let intensityLine: String
        if heaviestSetWeight > 0 {
            intensityLine = "Top set: \(WeightDisplay.formatted(heaviestSetWeight, unit: weightUnit)) x \(heaviestSetReps)."
        } else {
            intensityLine = "Cardio and recovery effort logged."
        }

        let volumeLine: String
        if totalVolume > 0 {
            volumeLine = "Total lifting volume: \(WeightDisplay.formatted(totalVolume, unit: weightUnit))."
        } else if totalReps > 0 {
            volumeLine = "Total reps completed: \(totalReps)."
        } else {
            volumeLine = "Session completed and saved."
        }

        let prLine: String
        if prHitsThisSession > 0 {
            prLine = "PR alert: \(prHitsThisSession) new PR \(prHitsThisSession == 1 ? "set" : "sets") this session."
        } else {
            prLine = "No PR today, but this work sets up your next PR."
        }

        return "\(consistencyLine) \(intensityLine) \(volumeLine) \(prLine)"
    }

    private func preloadFromMostRecentMatchingSession() -> Int {
        let now = Date()
        let candidateDays = primaryWorkoutDays
            .filter {
                $0.persistentModelID != day.persistentModelID &&
                $0.dayIndex == day.dayIndex &&
                $0.sessionCompletedAt != nil &&
                ($0.sessionCompletedAt ?? .distantPast) < now
            }
            .sorted { ($0.sessionCompletedAt ?? .distantPast) > ($1.sessionCompletedAt ?? .distantPast) }
        guard !candidateDays.isEmpty else { return 0 }

        var filledCount = 0
        for exercise in day.exercises where exercise.kind == .strength {
            // Find the latest matching exercise with at least one non-zero set.
            let matchingPreviousExercise: Exercise? = candidateDays.compactMap { previousDay in
                previousDay.exercises.first {
                    $0.kind == exercise.kind &&
                    normalizeExerciseName($0.name) == normalizeExerciseName(exercise.name) &&
                    $0.sortedSetLogs.contains(where: { $0.reps > 0 || $0.weight > 0 })
                }
            }.first

            guard let matchingPreviousExercise else { continue }

            let previousSets = matchingPreviousExercise.sortedSetLogs.filter { $0.reps > 0 || $0.weight > 0 }
            guard !previousSets.isEmpty else { continue }

            let previousByIndex = Dictionary(uniqueKeysWithValues: previousSets.map { ($0.setIndex, $0) })
            let fallbackSet = previousSets.last

            for setLog in exercise.sortedSetLogs {
                // Only prefill untouched values so we don't overwrite user input.
                guard setLog.reps == 0, setLog.weight == 0 else { continue }
                let source = previousByIndex[setLog.setIndex] ?? fallbackSet
                guard let source else { continue }
                if source.reps == 0, source.weight == 0 { continue }
                setLog.reps = source.reps
                setLog.weight = source.weight
                filledCount += 1
            }
        }
        return filledCount
    }

    private func normalizeExerciseName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

// MARK: - Exercise card

private struct ExerciseSessionCard: View {
    @Bindable var exercise: Exercise
    var workoutDay: WorkoutDay
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlayerStats.id) private var statsRows: [PlayerStats]
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue
    @State private var isEditingSets = false
    @State private var showAlternatives = false
    @State private var bossBorderPulse = false
    var prHighlightSetIDs: Set<PersistentIdentifier>
    var onCardioCompletedChange: () -> Void
    var onSetCompletedChange: (SetLog, Bool) -> Void
    var onDeletedSetLog: (PersistentIdentifier) -> Void

    private var bossStatus: PREngine.BossRaidStatus {
        PREngine.bossRaidStatus(exercise: exercise, scheduledDay: workoutDay, in: modelContext)
    }

    private var isBossRaid: Bool { bossStatus.isBossRaid }
    private var strengthStat: Int { statsRows.first?.strengthStat ?? 0 }
    private var adjustedTargetText: String {
        RPGProgressionEngine.adjustedRepTargetText(
            base: exercise.displayTargetSetsReps,
            strengthStat: strengthStat,
            applies: RPGProgressionEngine.isHeavyBarbellCompound(exerciseName: exercise.name)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isBossRaid {
                bossRaidBanner
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: exercise.kind == .cardio ? "figure.walk" : "dumbbell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isBossRaid ? Color(red: 1, green: 0.35, blue: 0.32) : AppTheme.primaryBlue)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.system(.body, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.titleText)
                        .fixedSize(horizontal: false, vertical: true)

                    if exercise.kind == .strength {
                        Text("Target: \(adjustedTargetText)")
                            .font(.system(.caption, design: .default, weight: .medium))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }

                Spacer(minLength: 0)

                if exercise.kind == .strength {
                    HStack(spacing: 12) {
                        Button {
                            showAlternatives = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.mutedText)
                        .accessibilityLabel("Exercise substitutes")

                        Button {
                            isEditingSets.toggle()
                        } label: {
                            Label(
                                isEditingSets ? "Done" : "Edit sets",
                                systemImage: isEditingSets ? "checkmark" : "pencil"
                            )
                            .font(.system(.subheadline, design: .default, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.primaryBlue)
                    }
                }
            }

            if exercise.kind == .cardio {
                cardioContent
            } else {
                setsContent
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(
                    isBossRaid
                        ? Color(red: 0.12, green: 0.04, blue: 0.06)
                        : AppTheme.cardBackground
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isBossRaid
                        ? LinearGradient(
                            colors: [
                                Color.red.opacity(bossBorderPulse ? 0.95 : 0.45),
                                Color(red: 0.9, green: 0.15, blue: 0.12).opacity(bossBorderPulse ? 0.85 : 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [AppTheme.cardBorder, AppTheme.cardBorder], startPoint: .top, endPoint: .bottom),
                    lineWidth: isBossRaid ? (bossBorderPulse ? 3.5 : 2.5) : 1
                )
        }
        .shadow(
            color: isBossRaid ? Color.red.opacity(0.35) : AppTheme.cardShadow,
            radius: isBossRaid ? 14 : AppTheme.cardShadowRadius,
            x: 0,
            y: isBossRaid ? 6 : AppTheme.cardShadowY
        )
        .onAppear {
            guard isBossRaid else { return }
            bossBorderPulse = true
        }
        .onChange(of: isBossRaid) { _, on in
            bossBorderPulse = on
        }
        .animation(
            .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
            value: bossBorderPulse
        )
        .sheet(isPresented: $showAlternatives) {
            ExerciseAlternativesSheet(exerciseName: exercise.name) {
                showAlternatives = false
            }
        }
    }

    private var bossRaidBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.yellow)
            Text("WARNING: CLASS ADVANCEMENT BOSS")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.92, blue: 0.75))
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.02, blue: 0.06),
                    Color(red: 0.22, green: 0.02, blue: 0.08)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.red.opacity(0.65), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var cardioContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Duration / target")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
                    .textCase(.uppercase)
                    .tracking(0.4)
                TextField("e.g. 30 min", text: $exercise.targetSetsReps)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.softInput, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    .onChange(of: exercise.targetSetsReps) { _, _ in
                        try? modelContext.save()
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
                    .textCase(.uppercase)
                    .tracking(0.4)
                TextField("e.g. 30 min incline walk", text: $exercise.cardioDurationNote)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.softInput, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    .onChange(of: exercise.cardioDurationNote) { _, _ in
                        try? modelContext.save()
                    }
            }

            Toggle(isOn: $exercise.cardioCompleted) {
                Text("Completed")
                    .font(.body.weight(.medium))
            }
            .tint(.green)
            .onChange(of: exercise.cardioCompleted) { _, _ in
                onCardioCompletedChange()
            }
        }
    }

    private var setsContent: some View {
        VStack(spacing: 8) {
            setHeaderRow
            ForEach(exercise.sortedSetLogs, id: \.persistentModelID) { setLog in
                SetRowView(
                    setLog: setLog,
                    showPRGlow: prHighlightSetIDs.contains(setLog.persistentModelID),
                    suggestsPlateLoading: exercise.suggestsPlateLoading,
                    weightUnit: WeightUnit(rawValue: weightUnitRaw) ?? .lb,
                    onRemove: (isEditingSets && exercise.setLogs.count > 1) ? { removeSet(setLog) } : nil,
                    onCompletedChange: { onSetCompletedChange(setLog, $0) }
                )
            }

            Button {
                addSet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add set")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.primaryBlue)
            .padding(.top, 4)
        }
    }

    private var setHeaderRow: some View {
        HStack {
            Text("Set")
                .frame(width: 36, alignment: .leading)
            Text("Reps")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Weight")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("")
                .font(.system(.caption2, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
                .frame(width: 28, alignment: .center)
            Text("Done")
                .frame(width: 44, alignment: .center)
        }
        .font(.system(.caption2, design: .default, weight: .semibold))
        .foregroundStyle(AppTheme.mutedText)
        .textCase(.uppercase)
        .tracking(0.4)
    }

    private func normalizeSetIndices() {
        for (i, log) in exercise.sortedSetLogs.enumerated() {
            log.setIndex = i + 1
        }
    }

    private func addSet() {
        let ordered = exercise.sortedSetLogs
        let last = ordered.last
        let newLog = SetLog(
            setIndex: ordered.count + 1,
            reps: last?.reps ?? 0,
            weight: last?.weight ?? 0,
            isCompleted: false
        )
        newLog.exercise = exercise
        modelContext.insert(newLog)
        normalizeSetIndices()
        try? modelContext.save()
    }

    private func removeSet(_ setLog: SetLog) {
        guard exercise.setLogs.count > 1 else { return }
        let id = setLog.persistentModelID
        onDeletedSetLog(id)
        modelContext.delete(setLog)
        normalizeSetIndices()
        try? modelContext.save()
    }
}

private struct SessionActionButtonStyle: ButtonStyle {
    var tint: Color
    var isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.caption, design: .default, weight: .semibold))
            .foregroundStyle(.white.opacity(isDisabled ? 0.8 : 1))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(tint.opacity(isDisabled ? 0.45 : (configuration.isPressed ? 0.75 : 1)))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SessionPrimaryButtonStyle: ButtonStyle {
    var tint: Color
    var isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .default, weight: .semibold))
            .foregroundStyle(.white.opacity(isDisabled ? 0.82 : 1))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint.opacity(isDisabled ? 0.45 : (configuration.isPressed ? 0.75 : 1)))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SessionSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .default, weight: .semibold))
            .foregroundStyle(AppTheme.titleText.opacity(0.95))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.subtleFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SessionLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .default, weight: .semibold))
            .foregroundStyle(AppTheme.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

private struct SessionSummary: Identifiable, Equatable {
    let id = UUID()
    let dayTitle: String
    let completedSets: Int
    let totalReps: Int
    let totalVolume: Double
    let completedAt: Date
    let aiCoachRecap: String
}

private struct SessionSummarySheet: View {
    var summary: SessionSummary
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("Session Complete")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.titleText)
                Text(summary.dayTitle)
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.bodyText)

                HStack(spacing: 10) {
                    summaryTile(title: "Sets", value: "\(summary.completedSets)", icon: "list.number")
                    summaryTile(title: "Reps", value: "\(summary.totalReps)", icon: "repeat")
                    summaryTile(title: "Volume", value: WeightDisplay.formatted(summary.totalVolume, unit: weightUnit), icon: "scalemass")
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Label("AI Coach Recap", systemImage: "sparkles")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                    Text(summary.aiCoachRecap)
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .minimalCard(cornerRadius: 12)

                Text(summary.completedAt, style: .time)
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func summaryTile(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.primaryBlue)
            Text(value)
                .font(.system(.body, design: .default, weight: .semibold))
            Text(title)
                .font(.system(.caption2, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .minimalCard(cornerRadius: 12)
    }
}

// MARK: - Set row

private struct SetRowView: View {
    @Bindable var setLog: SetLog
    var showPRGlow: Bool
    var suggestsPlateLoading: Bool
    var weightUnit: WeightUnit
    var onRemove: (() -> Void)?
    var onCompletedChange: (Bool) -> Void

    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @State private var showPlateSheet = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case reps, weight
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(setLog.setIndex)")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .monospacedDigit()
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(AppTheme.bodyText)

            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(AppTheme.softInput, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                .onChange(of: repsText) { _, newValue in
                    setLog.reps = Int(newValue.filter(\.isNumber)) ?? 0
                }

            HStack(spacing: 6) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AppTheme.softInput, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                    .onChange(of: weightText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                        setLog.weight = Double(filtered) ?? 0
                    }

                if suggestsPlateLoading && focusedField == .weight {
                    Button {
                        showPlateSheet = true
                    } label: {
                        Image(systemName: "circle.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryBlue)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Plate helper")
                }
            }
            .frame(maxWidth: .infinity)

            if let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.red.opacity(0.75))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove set")
                .frame(width: 28, alignment: .center)
            } else {
                Color.clear.frame(width: 28)
            }

            Button {
                let next = !setLog.isCompleted
                setLog.isCompleted = next
                onCompletedChange(next)
            } label: {
                ZStack {
                    Circle()
                        .stroke(setLog.isCompleted ? AppTheme.primaryBlue : AppTheme.mutedText.opacity(0.55), lineWidth: 2)
                        .background {
                            Circle()
                                .fill(setLog.isCompleted ? AppTheme.primaryBlue : Color.clear)
                        }
                    if setLog.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundStyle(.white)
                    }

                    if showPRGlow {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow.opacity(0.95))
                            .offset(x: 14, y: -14)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(setLog.isCompleted ? "Mark set incomplete" : "Mark set complete")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous)
                .fill(showPRGlow ? Color.yellow.opacity(AppTheme.isDarkModeEnabled ? 0.18 : 0.12) : AppTheme.subtleFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous)
                .strokeBorder(showPRGlow ? Color.yellow.opacity(0.68) : AppTheme.cardBorder, lineWidth: 1.2)
        }
        .animation(.easeInOut(duration: 0.25), value: showPRGlow)
        .sheet(isPresented: $showPlateSheet) {
            PlateLoadingSheet(totalDisplay: effectiveWeightForPlates, unit: weightUnit)
        }
        .onAppear { syncFieldsFromModel() }
        .onChange(of: setLog.reps) { _, _ in
            if focusedField != .reps { repsText = displayReps(setLog.reps) }
        }
        .onChange(of: setLog.weight) { _, _ in
            if focusedField != .weight { weightText = displayWeight(setLog.weight) }
        }
    }

    private func syncFieldsFromModel() {
        repsText = displayReps(setLog.reps)
        weightText = displayWeight(setLog.weight)
    }

    private func displayReps(_ value: Int) -> String {
        value == 0 ? "" : String(value)
    }

    private func displayWeight(_ value: Double) -> String {
        if value == 0 { return "" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    /// Weight value for plate math: live field while editing, otherwise model.
    private var effectiveWeightForPlates: Double {
        let filtered = weightText.filter { $0.isNumber || $0 == "." }
        if let v = Double(filtered), v > 0 { return v }
        return setLog.weight
    }
}

// MARK: - Milestone celebration

private struct MilestoneCelebrationOverlay: View {
    var celebration: MilestoneCelebration
    var onDismiss: () -> Void

    @State private var animateIn = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.05, green: 0.04, blue: 0.12).opacity(0.74))
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            SparkleField()
                .opacity(animateIn ? 1 : 0)
                .animation(.easeInOut(duration: 0.55), value: animateIn)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.35, blue: 0.98),
                                Color(red: 0.95, green: 0.35, blue: 0.65),
                                Color(red: 1.0, green: 0.55, blue: 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: 360, minHeight: 280)
                    .overlay {
                        RoundedRectangle(cornerRadius: 29, style: .continuous)
                            .fill(Color(red: 0.07, green: 0.08, blue: 0.14))
                            .padding(3)
                            .overlay(content: celebrationContent)
                    }
                    .shadow(color: Color.purple.opacity(0.35), radius: 18)
                    .shadow(color: Color.orange.opacity(0.28), radius: 22)
            }
            .padding(.horizontal, 24)
            .scaleEffect(animateIn ? 1 : 0.78)
            .opacity(animateIn ? 1 : 0)
            .animation(.spring(response: 0.46, dampingFraction: 0.75), value: animateIn)
        }
        .onTapGesture {
            onDismiss()
        }
        .onAppear {
            animateIn = true
        }
    }

    @ViewBuilder
    private func celebrationContent() -> some View {
        VStack(spacing: 12) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.9), Color.pink.opacity(0.65), Color.clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 52
                    )
                )
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: celebration.systemImage)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 22)

            Text("MILESTONE")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.78, green: 0.65, blue: 1.0))
                .tracking(1.4)

            Text(celebration.title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Text(celebration.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 2)

            Button {
                onDismiss()
            } label: {
                Text("Love it")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.74))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.9))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
    }
}

// MARK: - PR celebration

private struct PRCelebrationState {
    var exerciseName: String
    var weight: Double
    var reps: Int
    var previousPR: Double?
    var isBossRaid: Bool
}

// MARK: - Boss defeat (PR on raid)

private struct BossShakeEffect: GeometryEffect {
    var travel: CGFloat
    var shakes: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = travel * sin(animatableData * .pi * shakes)
        let ty = travel * 0.4 * cos(animatableData * .pi * (shakes + 0.5))
        return ProjectionTransform(CGAffineTransform(translationX: t, y: ty))
    }
}

private struct BossDefeatedOverlay: View {
    var exerciseName: String
    var weight: Double
    var reps: Int
    var previousPR: Double?
    var onDismiss: () -> Void

    @State private var animateIn = false
    @State private var shakeAmount: CGFloat = 0
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.01, blue: 0.02),
                            Color(red: 0.18, green: 0.02, blue: 0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(0.94)
                )
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.55, green: 0.08, blue: 0.1).opacity(0.45),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.42, green: 0.06, blue: 0.08),
                                Color(red: 0.12, green: 0.02, blue: 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: 360, minHeight: 320)
                    .overlay {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1, green: 0.82, blue: 0.35),
                                        Color(red: 0.75, green: 0.45, blue: 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .padding(2)
                    }
                    .overlay { bossContent }
                    .shadow(color: Color(red: 0.9, green: 0.35, blue: 0.12).opacity(0.55), radius: 28)
            }
            .padding(.horizontal, 22)
            .scaleEffect(animateIn ? 1 : 0.72)
            .opacity(animateIn ? 1 : 0)
            .modifier(BossShakeEffect(travel: 11, shakes: 6, animatableData: shakeAmount))
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: animateIn)
        }
        .onTapGesture { onDismiss() }
        .onAppear {
            animateIn = true
            withAnimation(.easeOut(duration: 0.5)) {
                shakeAmount = 1
            }
        }
    }

    @ViewBuilder
    private var bossContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.92, blue: 0.45),
                            Color(red: 0.95, green: 0.55, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.orange.opacity(0.75), radius: 12)
                .padding(.top, 26)

            Text("BOSS DEFEATED")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.9, blue: 0.45),
                            Color(red: 1, green: 0.72, blue: 0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)

            Text("+3 STAT POINTS ACQUIRED")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.5))
                .tracking(0.8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            VStack(spacing: 6) {
                Text("\(WeightDisplay.formatted(weight, unit: weightUnit)) × \(reps) · \(exerciseName)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .multilineTextAlignment(.center)

                Text(previousPRSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.top, 4)

            Button {
                onDismiss()
            } label: {
                Text("Claim reward")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.15, green: 0.05, blue: 0.02))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1, green: 0.88, blue: 0.42),
                                        Color(red: 0.92, green: 0.62, blue: 0.18)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 26)
        }
    }

    private var previousPRSubtitle: String {
        guard let previousPR, previousPR > 0 else {
            return "New all-time record logged"
        }
        return "Previous best: \(WeightDisplay.formatted(previousPR, unit: weightUnit))"
    }
}

private struct PRCelebrationOverlay: View {
    var exerciseName: String
    var weight: Double
    var reps: Int
    var previousPR: Double?
    var onDismiss: () -> Void

    @State private var animateIn = false
    @AppStorage("weightUnit") private var weightUnitRaw = WeightUnit.lb.rawValue

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lb
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.02, green: 0.04, blue: 0.09).opacity(0.72))
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            SparkleField()
                .opacity(animateIn ? 1 : 0)
                .animation(.easeInOut(duration: 0.55), value: animateIn)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.13, green: 0.94, blue: 0.86),
                                Color(red: 1.0, green: 0.76, blue: 0.20),
                                Color(red: 1.0, green: 0.56, blue: 0.17)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: 360, minHeight: 300)
                    .overlay {
                        RoundedRectangle(cornerRadius: 29, style: .continuous)
                            .fill(Color(red: 0.06, green: 0.09, blue: 0.16))
                            .padding(3)
                            .overlay(content: celebrationContent)
                    }
                    .shadow(color: Color(red: 0.06, green: 0.95, blue: 0.84).opacity(0.4), radius: 20)
                    .shadow(color: Color.orange.opacity(0.38), radius: 24)
            }
            .padding(.horizontal, 24)
            .scaleEffect(animateIn ? 1 : 0.78)
            .opacity(animateIn ? 1 : 0)
            .animation(.spring(response: 0.46, dampingFraction: 0.75), value: animateIn)
        }
        .onTapGesture {
            onDismiss()
        }
        .onAppear {
            animateIn = true
        }
    }

    @ViewBuilder
    private func celebrationContent() -> some View {
        VStack(spacing: 12) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.93), Color.orange.opacity(0.78), Color.clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 52
                    )
                )
                .frame(width: 92, height: 92)
                .overlay {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(-16))
                }
                .padding(.top, 24)

            Text("NEW PERSONAL RECORD!")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.44))
                .multilineTextAlignment(.center)
                .shadow(color: Color.yellow.opacity(0.7), radius: 9)
                .padding(.horizontal, 20)

            Text("YOU DID IT!")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.36, green: 0.95, blue: 0.90))
                .tracking(1.2)

            VStack(spacing: 5) {
                Text("\(WeightDisplay.formatted(weight, unit: weightUnit)) \(exerciseName)")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("at \(reps) reps")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.84))

                Text(previousPRText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .padding(.top, 6)
            .padding(.horizontal, 14)

            Button {
                onDismiss()
            } label: {
                Text("Awesome")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.74))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.9))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }

    private var previousPRText: String {
        guard let previousPR, previousPR > 0 else {
            return "First recorded PR"
        }
        return "Prev PR: \(WeightDisplay.formatted(previousPR, unit: weightUnit))"
    }
}

private struct ExerciseAlternativesSheet: View {
    var exerciseName: String
    var onDismiss: () -> Void

    private var ideas: [String] {
        ExerciseAlternatives.alternatives(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Swap \(exerciseName) when equipment is busy or you need a joint-friendly option. Rename the exercise on the card if you switch.")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                        .listRowBackground(AppTheme.cardBackground)
                }

                Section("Ideas") {
                    ForEach(Array(ideas.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.body, design: .default, weight: .medium))
                            .foregroundStyle(AppTheme.titleText)
                            .listRowBackground(AppTheme.cardBackground)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Substitutes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }
}

private struct SparkleField: View {
    @State private var twinkle = false

    var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { idx in
                Circle()
                    .fill(idx.isMultiple(of: 2) ? Color.cyan.opacity(0.55) : Color.yellow.opacity(0.55))
                    .frame(width: CGFloat(4 + (idx % 4)), height: CGFloat(4 + (idx % 4)))
                    .position(
                        x: CGFloat(40 + (idx * 17) % 330),
                        y: CGFloat(70 + (idx * 29) % 560)
                    )
                    .opacity(twinkle ? 1 : 0.18)
                    .blur(radius: twinkle ? 0 : 2)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever().delay(Double(idx) * 0.03),
                        value: twinkle
                    )
            }
        }
        .onAppear { twinkle = true }
    }
}

#Preview("Session · Day 1") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WorkoutProgram.self,
        WorkoutDay.self,
        Exercise.self,
        SetLog.self,
        CompletedWorkoutSession.self,
        CompletedExerciseSnapshot.self,
        CompletedSetSnapshot.self,
        PersonalRecord.self,
        PlayerStats.self,
        configurations: config
    )
    let context = ModelContext(container)
    WorkoutProgramSeed.insertDefaultProgramIfNeeded(in: context)
    PlayerStats.ensureExists(in: context)
    let program = try! context.fetch(FetchDescriptor<WorkoutProgram>()).first!
    let day1 = program.days.first { $0.dayIndex == 1 }!

    return NavigationStack {
        WorkoutSessionView(day: day1)
    }
    .modelContainer(container)
}
