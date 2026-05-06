import Foundation

/// Curated substitution ideas per exercise (name must match seed / your program spelling loosely).
enum ExerciseAlternatives {
    static func alternatives(for exerciseName: String) -> [String] {
        let key = exerciseName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return lookup[key] ?? defaultAlternatives
    }

    static let defaultAlternatives: [String] = [
        "Choose a similar movement for the same muscle group",
        "Match intensity — same rep range if possible",
        "Log weights when you substitute"
    ]

    private static let lookup: [String: [String]] = [
        "barbell bench press": [
            "Dumbbell bench press",
            "Smith machine bench",
            "Push-ups (weighted if needed)",
            "Machine chest press"
        ],
        "incline dumbbell": [
            "Incline barbell bench",
            "Incline Smith press",
            "Low cable fly crossover"
        ],
        "incline dumbbell press": [
            "Incline barbell bench",
            "Incline Smith press",
            "Low cable fly crossover"
        ],
        "cable chest fly": [
            "Pec deck",
            "Dumbbell fly",
            "Low-to-high cable fly"
        ],
        "tricep pushdown": [
            "Overhead cable extension",
            "Skull crusher",
            "Close-grip bench",
            "Machine dip"
        ],
        "overhead tricep": [
            "Cable overhead extension",
            "Single-arm dumbbell extension",
            "Tricep pushdown"
        ],
        "overhead tricep extension": [
            "Cable overhead extension",
            "Single-arm dumbbell extension",
            "Tricep pushdown"
        ],
        "barbell row": [
            "Dumbbell row",
            "T-bar row",
            "Chest-supported machine row",
            "Seal row"
        ],
        "lat pulldown": [
            "Pull-up / assisted pull-up",
            "Straight-arm pulldown",
            "Machine pullover"
        ],
        "seated cable row": [
            "One-arm cable row",
            "Machine row",
            "Chest-supported T-bar"
        ],
        "barbell bicep curl": [
            "Dumbbell curl",
            "Cable curl",
            "Preacher curl",
            "Machine curl"
        ],
        "hammer curl": [
            "Cross-body hammer curl",
            "Rope cable curl",
            "Neutral-grip pull-up (if applicable)"
        ],
        "hack squat": [
            "Leg press (feet low)",
            "Goblet squat",
            "Front squat",
            "Belt squat (if available)"
        ],
        "leg press": [
            "Hack squat",
            "Smith squat",
            "Goblet squat"
        ],
        "leg curl machine": [
            "Nordic curl (assisted)",
            "Stability ball leg curl",
            "Romanian deadlift (lighter)"
        ],
        "leg extension": [
            "Spanish squat",
            "Sissy squat (assisted)",
            "Terminal knee extension band"
        ],
        "standing calf raise": [
            "Seated calf raise",
            "Leg press calf press",
            "Smith calf raise"
        ],
        "dumbbell shoulder press": [
            "Machine shoulder press",
            "Arnold press",
            "Landmine press",
            "Single-arm dumbbell press"
        ],
        "lateral raises": [
            "Cable lateral raise",
            "Machine lateral raise",
            "Leaning cable lateral"
        ],
        "rear delt fly": [
            "Face pull",
            "Reverse pec deck",
            "Cable reverse fly"
        ],
        "cable crunch": [
            "Machine crunch",
            "Weighted decline crunch",
            "Dead bug / plank progression"
        ],
        "hanging leg raise": [
            "Captain's chair knee raise",
            "Lying leg raise",
            "Ab wheel (knees)"
        ],
        "hanging leg raises": [
            "Captain's chair knee raise",
            "Lying leg raise",
            "Ab wheel (knees)"
        ],
        "incline bench press": [
            "Incline dumbbell press",
            "Incline Smith press",
            "Low incline machine press"
        ],
        "pull ups (or assisted)": [
            "Lat pulldown",
            "Assisted pull-up machine",
            "Band-assisted pull-up"
        ],
        "chest supported row": [
            "Seal row",
            "Chest-supported T-bar",
            "Incline dumbbell row"
        ],
        "ez bar curl": [
            "Dumbbell curl",
            "Cable bar curl",
            "Preacher curl"
        ],
        "tricep dips": [
            "Bench dip",
            "Machine dip",
            "Close-grip push-up"
        ],
        "walking": [
            "Bike (easy)",
            "Elliptical",
            "Swim (easy)"
        ],
        "planks": [
            "Dead bug",
            "Pallof press",
            "Side plank"
        ],
        "cardio": [
            "Bike",
            "Elliptical",
            "Stair climber",
            "Any zone-2 you enjoy"
        ]
    ]
}
