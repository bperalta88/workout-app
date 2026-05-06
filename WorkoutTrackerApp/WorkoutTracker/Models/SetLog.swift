import Foundation
import SwiftData

@Model
final class SetLog {
    var setIndex: Int
    var reps: Int
    var weight: Double
    var isCompleted: Bool

    var exercise: Exercise?

    init(setIndex: Int, reps: Int, weight: Double, isCompleted: Bool = false) {
        self.setIndex = setIndex
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
    }
}
