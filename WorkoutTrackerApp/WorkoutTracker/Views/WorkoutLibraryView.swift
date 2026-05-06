import SwiftUI

/// Browse planned exercises and substitution ideas for your active program.
struct WorkoutLibraryView: View {
    var primaryDays: [WorkoutDay]
    @State private var query = ""

    private var filteredDays: [WorkoutDay] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return primaryDays }
        return primaryDays.filter { day in
            day.focus.lowercased().contains(q) ||
            day.exercises.contains { $0.name.lowercased().contains(q) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tap an exercise to see substitute ideas. Use the swap button during a session for the same list.")
                    .font(.system(.subheadline, design: .default, weight: .regular))
                    .foregroundStyle(AppTheme.bodyText)

                ForEach(filteredDays, id: \.persistentModelID) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Day \(day.dayIndex)")
                                .font(.system(.caption, design: .default, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryBlue)
                            Text("•")
                                .foregroundStyle(AppTheme.mutedText)
                            Text(day.focus)
                                .font(.system(.subheadline, design: .default, weight: .semibold))
                                .foregroundStyle(AppTheme.titleText)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(day.sortedExercises, id: \.persistentModelID) { ex in
                                if ex.kind == .strength {
                                    NavigationLink {
                                        ExerciseAlternativesLibraryDetail(exerciseName: ex.name, target: ex.displayTargetSetsReps)
                                    } label: {
                                        HStack {
                                            Text(ex.name)
                                                .font(.system(.body, design: .default, weight: .medium))
                                                .foregroundStyle(AppTheme.titleText)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                            Text(ex.displayTargetSetsReps)
                                                .font(.system(.caption, design: .default, weight: .medium))
                                                .foregroundStyle(AppTheme.mutedText)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(AppTheme.mutedText.opacity(0.7))
                                        }
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    HStack {
                                        Image(systemName: "figure.walk")
                                            .foregroundStyle(AppTheme.primaryBlue)
                                        Text(ex.name)
                                            .font(.system(.body, design: .default, weight: .medium))
                                            .foregroundStyle(AppTheme.titleText)
                                        Spacer()
                                        Text(ex.targetSetsReps)
                                            .font(.system(.caption, design: .default, weight: .medium))
                                            .foregroundStyle(AppTheme.mutedText)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
                }
            }
            .padding(.bottom, 110)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search day or exercise")
    }
}

private struct ExerciseAlternativesLibraryDetail: View {
    var exerciseName: String
    var target: String

    private var ideas: [String] {
        ExerciseAlternatives.alternatives(for: exerciseName)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(exerciseName)
                    .font(.system(.title3, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Text("Plan target: \(target)")
                    .font(.system(.subheadline, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(ideas.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryBlue)
                                .padding(.top, 2)
                            Text(line)
                                .font(.system(.body, design: .default, weight: .regular))
                                .foregroundStyle(AppTheme.bodyText)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .minimalCard(cornerRadius: 12)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Substitutes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
