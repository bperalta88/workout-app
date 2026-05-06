import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Bindable var day: WorkoutDay
    @Environment(\.modelContext) private var modelContext

    @State private var prHighlightSetIDs: Set<PersistentIdentifier> = []
    @State private var prCelebration: PRCelebrationState?
    @State private var isPRModalPresented = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(day.sortedExercises, id: \.persistentModelID) { exercise in
                    ExerciseSessionCard(
                        exercise: exercise,
                        prHighlightSetIDs: prHighlightSetIDs,
                        onSetCompletedChange: { setLog, completed in
                            handleSetCompletion(exercise: exercise, setLog: setLog, completed: completed)
                        }
                    )
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
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(day.focus)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.bodyText)
                }
            }
        }
        .overlay {
            if isPRModalPresented, let celebration = prCelebration {
                PRCelebrationOverlay(
                    exerciseName: celebration.exerciseName,
                    weight: celebration.weight,
                    reps: celebration.reps,
                    previousPR: celebration.previousPR,
                    onDismiss: {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                            isPRModalPresented = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            prCelebration = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isPRModalPresented)
    }

    private func handleSetCompletion(exercise: Exercise, setLog: SetLog, completed: Bool) {
        guard exercise.kind == .strength, completed else {
            prHighlightSetIDs.remove(setLog.persistentModelID)
            return
        }

        let result = PREngine.evaluateCompletionForPersonalRecord(
            exerciseName: exercise.name,
            weight: setLog.weight,
            reps: setLog.reps,
            in: modelContext
        )

        if result.isNewRecord {
            try? modelContext.save()
            prHighlightSetIDs.insert(setLog.persistentModelID)
            prCelebration = PRCelebrationState(
                exerciseName: exercise.name,
                weight: result.currentWeight,
                reps: result.currentReps,
                previousPR: result.previousMaxWeight
            )
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                isPRModalPresented = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                if isPRModalPresented {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        isPRModalPresented = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        prCelebration = nil
                    }
                }
            }
        } else {
            prHighlightSetIDs.remove(setLog.persistentModelID)
        }
    }
}

// MARK: - Exercise card

private struct ExerciseSessionCard: View {
    @Bindable var exercise: Exercise
    var prHighlightSetIDs: Set<PersistentIdentifier>
    var onSetCompletedChange: (SetLog, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.titleText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.mutedText)
                        Text("Target: \(exercise.targetSetsReps)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.bodyText)
                    }
                }
                Spacer(minLength: 0)
            }

            if exercise.kind == .cardio {
                cardioContent
            } else {
                setsContent
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.03), lineWidth: 1)
        }
        .shadow(color: AppTheme.cardShadow, radius: 12, x: 0, y: 5)
    }

    @ViewBuilder
    private var cardioContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !exercise.cardioDurationNote.isEmpty {
                Label(exercise.cardioDurationNote, systemImage: "figure.walk")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $exercise.cardioCompleted) {
                Text("Completed")
                    .font(.body.weight(.medium))
            }
            .tint(.green)
        }
    }

    private var setsContent: some View {
        VStack(spacing: 8) {
            setHeaderRow
            ForEach(exercise.sortedSetLogs, id: \.persistentModelID) { setLog in
                SetRowView(
                    setLog: setLog,
                    showPRGlow: prHighlightSetIDs.contains(setLog.persistentModelID),
                    onCompletedChange: { onSetCompletedChange(setLog, $0) }
                )
            }
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
            Text("Done")
                .frame(width: 44, alignment: .center)
        }
        .font(.system(.caption, design: .rounded, weight: .bold))
        .foregroundStyle(AppTheme.mutedText)
        .textCase(.uppercase)
    }
}

// MARK: - Set row

private struct SetRowView: View {
    @Bindable var setLog: SetLog
    var showPRGlow: Bool
    var onCompletedChange: (Bool) -> Void

    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case reps, weight
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(setLog.setIndex)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
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
                            .font(.system(size: 12, weight: .bold, design: .rounded))
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
                .fill(showPRGlow ? Color.yellow.opacity(0.12) : Color.white.opacity(0.78))
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous)
                .strokeBorder(showPRGlow ? Color.yellow.opacity(0.68) : Color.black.opacity(0.03), lineWidth: 1.2)
        }
        .animation(.easeInOut(duration: 0.25), value: showPRGlow)
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
}

// MARK: - PR celebration

private struct PRCelebrationState {
    var exerciseName: String
    var weight: Double
    var reps: Int
    var previousPR: Double?
}

private struct PRCelebrationOverlay: View {
    var exerciseName: String
    var weight: Double
    var reps: Int
    var previousPR: Double?
    var onDismiss: () -> Void

    @State private var animateIn = false

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
                Text("\(displayWeight(weight)) lb \(exerciseName)")
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
        return "Prev PR: \(displayWeight(previousPR)) lb"
    }

    private func displayWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
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
        PersonalRecord.self,
        configurations: config
    )
    let context = ModelContext(container)
    WorkoutProgramSeed.insertDefaultProgramIfNeeded(in: context)
    let program = try! context.fetch(FetchDescriptor<WorkoutProgram>()).first!
    let day1 = program.days.first { $0.dayIndex == 1 }!

    return NavigationStack {
        WorkoutSessionView(day: day1)
    }
    .modelContainer(container)
}
