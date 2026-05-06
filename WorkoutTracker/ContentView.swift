import SwiftUI
import SwiftData

/// Temporary root for development — replace with Home / History / Stats tabs in a later step.
struct ContentView: View {
    @Query(sort: \WorkoutDay.dayIndex) private var workoutDays: [WorkoutDay]

    var body: some View {
        NavigationStack {
            List {
                Section("Workout session (preview)") {
                    ForEach(workoutDays, id: \.persistentModelID) { day in
                        NavigationLink {
                            WorkoutSessionView(day: day)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Day \(day.dayIndex)")
                                    .font(.headline)
                                Text(day.focus)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Workout Tracker")
        }
    }
}
