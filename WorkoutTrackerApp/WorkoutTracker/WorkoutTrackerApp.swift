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
            CompletedWorkoutSession.self,
            CompletedExerciseSnapshot.self,
            CompletedSetSnapshot.self,
            PersonalRecord.self,
            PlayerStats.self,
            DailyQuestClaim.self,
            MealLog.self,
            SavedFood.self,
        ])
        modelContainer = Self.makeContainer(schema: schema)

        let context = ModelContext(modelContainer)
        WorkoutProgramSeed.insertDefaultProgramIfNeeded(in: context)
        PlayerStats.ensureExists(in: context)
        try? context.save()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }

    private static func makeContainer(schema: Schema) -> ModelContainer {
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WorkoutTracker.store")
        let configuration = ModelConfiguration(url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Personal app fallback: if schema changed, reset local store and rebuild.
            let cleanupURLs = [
                storeURL,
                storeURL.appendingPathExtension("wal"),
                storeURL.appendingPathExtension("shm")
            ]
            cleanupURLs.forEach { try? FileManager.default.removeItem(at: $0) }

            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Failed to initialize local store: \(error.localizedDescription)")
            }
        }
    }
}
