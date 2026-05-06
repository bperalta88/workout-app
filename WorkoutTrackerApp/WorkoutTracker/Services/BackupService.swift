import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct WorkoutBackupPayload: Codable {
    var exportedAt: Date
    var programs: [ProgramDTO]
    var personalRecords: [PersonalRecordDTO]
}

struct ProgramDTO: Codable {
    var name: String
    var createdAt: Date
    var days: [WorkoutDayDTO]
}

struct WorkoutDayDTO: Codable {
    var dayIndex: Int
    var focus: String
    var sessionStartedAt: Date?
    var sessionCompletedAt: Date?
    var isSessionActive: Bool
    var completionCount: Int
    var exercises: [ExerciseDTO]
}

struct ExerciseDTO: Codable {
    var name: String
    var targetSetsReps: String
    var kindRaw: String
    var sortOrder: Int
    var cardioCompleted: Bool
    var cardioDurationNote: String
    var setLogs: [SetLogDTO]
}

struct SetLogDTO: Codable {
    var setIndex: Int
    var reps: Int
    var weight: Double
    var isCompleted: Bool
}

struct PersonalRecordDTO: Codable {
    var exerciseName: String
    var maxWeight: Double
    var repsAtMaxWeight: Int
    var achievedAt: Date
}

struct BackupJSONDocument: FileDocument {
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

enum BackupService {
    static func exportBackup(from context: ModelContext) throws -> Data {
        let programs = try context.fetch(FetchDescriptor<WorkoutProgram>())
        let records = try context.fetch(FetchDescriptor<PersonalRecord>())

        let payload = WorkoutBackupPayload(
            exportedAt: .now,
            programs: programs.map(programDTO(from:)),
            personalRecords: records.map {
                PersonalRecordDTO(
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
        let payload = try decoder.decode(WorkoutBackupPayload.self, from: data)

        let existingPrograms = try context.fetch(FetchDescriptor<WorkoutProgram>())
        let existingRecords = try context.fetch(FetchDescriptor<PersonalRecord>())
        existingPrograms.forEach { context.delete($0) }
        existingRecords.forEach { context.delete($0) }

        for program in payload.programs {
            let modelProgram = WorkoutProgram(name: program.name, createdAt: program.createdAt)
            modelProgram.days = program.days.map { dayDTO in
                let modelDay = WorkoutDay(
                    dayIndex: dayDTO.dayIndex,
                    focus: dayDTO.focus,
                    sessionStartedAt: dayDTO.sessionStartedAt,
                    sessionCompletedAt: dayDTO.sessionCompletedAt,
                    isSessionActive: dayDTO.isSessionActive,
                    completionCount: dayDTO.completionCount
                )
                modelDay.exercises = dayDTO.exercises.map { exerciseDTO in
                    let modelExercise = Exercise(
                        name: exerciseDTO.name,
                        targetSetsReps: exerciseDTO.targetSetsReps,
                        kind: ExerciseKind(rawValue: exerciseDTO.kindRaw) ?? .strength,
                        sortOrder: exerciseDTO.sortOrder,
                        cardioCompleted: exerciseDTO.cardioCompleted,
                        cardioDurationNote: exerciseDTO.cardioDurationNote,
                        setLogs: exerciseDTO.setLogs.map { setDTO in
                            SetLog(
                                setIndex: setDTO.setIndex,
                                reps: setDTO.reps,
                                weight: setDTO.weight,
                                isCompleted: setDTO.isCompleted
                            )
                        }
                    )
                    modelExercise.workoutDay = modelDay
                    modelExercise.setLogs.forEach { $0.exercise = modelExercise }
                    return modelExercise
                }
                modelDay.program = modelProgram
                return modelDay
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

    private static func programDTO(from program: WorkoutProgram) -> ProgramDTO {
        ProgramDTO(
            name: program.name,
            createdAt: program.createdAt,
            days: program.days.map { day in
                WorkoutDayDTO(
                    dayIndex: day.dayIndex,
                    focus: day.focus,
                    sessionStartedAt: day.sessionStartedAt,
                    sessionCompletedAt: day.sessionCompletedAt,
                    isSessionActive: day.isSessionActive,
                    completionCount: day.completionCount,
                    exercises: day.exercises.map { exercise in
                        ExerciseDTO(
                            name: exercise.name,
                            targetSetsReps: exercise.targetSetsReps,
                            kindRaw: exercise.kindRaw,
                            sortOrder: exercise.sortOrder,
                            cardioCompleted: exercise.cardioCompleted,
                            cardioDurationNote: exercise.cardioDurationNote,
                            setLogs: exercise.setLogs.map { setLog in
                                SetLogDTO(
                                    setIndex: setLog.setIndex,
                                    reps: setLog.reps,
                                    weight: setLog.weight,
                                    isCompleted: setLog.isCompleted
                                )
                            }
                        )
                    }
                )
            }
        )
    }
}
