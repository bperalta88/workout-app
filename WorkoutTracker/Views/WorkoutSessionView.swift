import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @Bindable var day: WorkoutDay
    @Environment(\.modelContext) private var modelContext

    @State private var prToastExerciseName: String?
    @State private var prHighlightSetIDs: Set<PersistentIdentifier> = []

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
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Day \(day.dayIndex)")
                        .font(.headline)
                    Text(day.focus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay(alignment: .top) {
            if let name = prToastExerciseName {
                PRBanner(exerciseName: name)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: prToastExerciseName)
    }

    private func handleSetCompletion(exercise: Exercise, setLog: SetLog, completed: Bool) {
        guard exercise.kind == .strength, completed else {
            prHighlightSetIDs.remove(setLog.persistentModelID)
            return
        }

        let isPR = PREngine.registerCompletionIfPersonalRecord(
            exerciseName: exercise.name,
            weight: setLog.weight,
            reps: setLog.reps,
            in: modelContext
        )

        if isPR {
            try? modelContext.save()
            prHighlightSetIDs.insert(setLog.persistentModelID)
            prToastExerciseName = exercise.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                if prToastExerciseName == exercise.name {
                    prToastExerciseName = nil
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Target: \(exercise.targetSetsReps)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
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
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
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
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: 36, alignment: .leading)
                .foregroundStyle(.secondary)

            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .reps)
                .frame(maxWidth: .infinity)
                .onChange(of: repsText) { _, newValue in
                    setLog.reps = Int(newValue.filter(\.isNumber)) ?? 0
                }

            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .weight)
                .frame(maxWidth: .infinity)
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
                    Image(systemName: setLog.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(setLog.isCompleted ? Color.green : Color.secondary)

                    if showPRGlow {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(showPRGlow ? Color.yellow.opacity(0.12) : Color(.tertiarySystemFill).opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(showPRGlow ? Color.yellow.opacity(0.55) : Color.clear, lineWidth: 1.5)
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

// MARK: - PR toast

private struct PRBanner: View {
    var exerciseName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("New PR!")
                    .font(.subheadline.weight(.bold))
                Text(exerciseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 20)
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
