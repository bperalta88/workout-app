import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            WorkoutProgram.self,
            WorkoutDay.self,
            Exercise.self,
            SetLog.self,
            PersonalRecord.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        modelContainer = try! ModelContainer(for: schema, configurations: configuration)

        let context = ModelContext(modelContainer)
        WorkoutProgramSeed.insertDefaultProgramIfNeeded(in: context)
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
