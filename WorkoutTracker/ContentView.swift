import SwiftUI
import SwiftData

/// Temporary root for development — replace with Home / History / Stats tabs in a later step.
struct ContentView: View {
    @Query(sort: \WorkoutDay.dayIndex) private var workoutDays: [WorkoutDay]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Workout Session")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.titleText)
                        .padding(.top, 6)

                    ForEach(workoutDays, id: \.persistentModelID) { day in
                        NavigationLink {
                            WorkoutSessionView(day: day)
                        } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(AppTheme.primaryBlue.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                    .overlay {
                                        Text("\(day.dayIndex)")
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .foregroundStyle(AppTheme.primaryBlue)
                                    }

                                Text("Day \(day.dayIndex)")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(AppTheme.titleText)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(day.focus)
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                        .foregroundStyle(AppTheme.bodyText)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.mutedText)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                            .shadow(color: AppTheme.cardShadow, radius: 14, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Workout Tracker")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.titleText)
                }
            }
        }
    }
}
