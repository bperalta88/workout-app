import Foundation
import SwiftData

enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }
}

@Model
final class MealLog {
    var loggedAt: Date
    /// `MealSlot.rawValue`
    var slotRaw: String
    var name: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var notes: String
    @Attribute(.externalStorage) var photoJPEG: Data?
    var usedPhotoEstimate: Bool
    /// Human-readable summary of on-device image labels (transparency / debugging).
    var visionSummary: String

    init(
        loggedAt: Date = .now,
        slot: MealSlot,
        name: String,
        calories: Double,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        notes: String = "",
        photoJPEG: Data? = nil,
        usedPhotoEstimate: Bool = false,
        visionSummary: String = ""
    ) {
        self.loggedAt = loggedAt
        self.slotRaw = slot.rawValue
        self.name = name
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.notes = notes
        self.photoJPEG = photoJPEG
        self.usedPhotoEstimate = usedPhotoEstimate
        self.visionSummary = visionSummary
    }

    var resolvedSlot: MealSlot { MealSlot(rawValue: slotRaw) ?? .snack }
}
