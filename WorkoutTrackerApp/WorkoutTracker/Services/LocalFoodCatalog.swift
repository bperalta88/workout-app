import Foundation

/// Foods for manual **Browse** and **on-device** photo suggestions (keyword match after Vision labels).
enum LocalFoodCatalog {
    struct Entry: Identifiable, Hashable, Sendable {
        let id: String
        let displayName: String
        let matchKeys: [String]
        let kcalPer100g: Double
        let proteinPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        let defaultServingG: Double

        func macros(forServingGrams grams: Double) -> (cal: Double, p: Double, c: Double, f: Double) {
            let r = grams / 100
            return (
                kcalPer100g * r,
                proteinPer100g * r,
                carbsPer100g * r,
                fatPer100g * r
            )
        }
    }

    static let entries: [Entry] = [
        Entry(id: "chicken_breast", displayName: "Chicken breast (grilled)", matchKeys: ["chicken", "poultry", "meat"], kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, defaultServingG: 170),
        Entry(id: "ground_beef", displayName: "Ground beef (lean)", matchKeys: ["beef", "burger", "hamburger", "steak"], kcalPer100g: 250, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 15, defaultServingG: 150),
        Entry(id: "salmon", displayName: "Salmon", matchKeys: ["salmon", "fish", "seafood", "sushi"], kcalPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13, defaultServingG: 150),
        Entry(id: "egg", displayName: "Eggs (whole)", matchKeys: ["egg", "omelet", "omelette"], kcalPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, defaultServingG: 100),
        Entry(id: "rice_white", displayName: "White rice (cooked)", matchKeys: ["rice", "jasmine", "basmati", "sticky rice", "steamed rice", "fried rice"], kcalPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, defaultServingG: 200),
        Entry(id: "rice_brown", displayName: "Brown rice (cooked)", matchKeys: ["brown rice"], kcalPer100g: 112, proteinPer100g: 2.6, carbsPer100g: 24, fatPer100g: 0.9, defaultServingG: 200),
        Entry(id: "pasta", displayName: "Pasta (cooked)", matchKeys: ["pasta", "noodle", "spaghetti", "macaroni"], kcalPer100g: 131, proteinPer100g: 5, carbsPer100g: 25, fatPer100g: 1.1, defaultServingG: 220),
        Entry(id: "bread", displayName: "Bread / toast", matchKeys: ["bread", "toast", "sandwich", "bagel", "bun"], kcalPer100g: 265, proteinPer100g: 9, carbsPer100g: 49, fatPer100g: 3.2, defaultServingG: 60),
        Entry(id: "pizza", displayName: "Pizza (slice est.)", matchKeys: ["pizza"], kcalPer100g: 266, proteinPer100g: 11, carbsPer100g: 33, fatPer100g: 10, defaultServingG: 130),
        Entry(id: "burrito", displayName: "Burrito / wrap", matchKeys: ["burrito", "wrap", "taco", "quesadilla"], kcalPer100g: 200, proteinPer100g: 10, carbsPer100g: 22, fatPer100g: 8, defaultServingG: 280),
        Entry(id: "salad", displayName: "Green salad (light dressing)", matchKeys: ["salad", "lettuce", "greens", "vegetable"], kcalPer100g: 45, proteinPer100g: 2, carbsPer100g: 6, fatPer100g: 2, defaultServingG: 200),
        Entry(id: "potato", displayName: "Potato (baked / roasted)", matchKeys: ["potato", "fries", "french fry", "mashed"], kcalPer100g: 93, proteinPer100g: 2.5, carbsPer100g: 21, fatPer100g: 0.1, defaultServingG: 200),
        Entry(id: "oatmeal", displayName: "Oatmeal (cooked)", matchKeys: ["oat", "porridge", "cereal"], kcalPer100g: 71, proteinPer100g: 2.5, carbsPer100g: 12, fatPer100g: 1.4, defaultServingG: 250),
        Entry(id: "yogurt", displayName: "Greek yogurt (plain)", matchKeys: ["yogurt", "yoghurt"], kcalPer100g: 97, proteinPer100g: 10, carbsPer100g: 3.6, fatPer100g: 5, defaultServingG: 200),
        Entry(id: "cheese", displayName: "Cheese (average)", matchKeys: ["cheese", "cheddar", "mozzarella"], kcalPer100g: 350, proteinPer100g: 22, carbsPer100g: 2, fatPer100g: 28, defaultServingG: 40),
        Entry(id: "milk", displayName: "Milk (2%)", matchKeys: ["milk", "dairy"], kcalPer100g: 50, proteinPer100g: 3.3, carbsPer100g: 5, fatPer100g: 2, defaultServingG: 240),
        Entry(id: "banana", displayName: "Banana", matchKeys: ["banana"], kcalPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, defaultServingG: 120),
        Entry(id: "apple", displayName: "Apple", matchKeys: ["apple"], kcalPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, defaultServingG: 180),
        Entry(id: "berries", displayName: "Berries (mixed)", matchKeys: ["berry", "strawberry", "blueberry"], kcalPer100g: 50, proteinPer100g: 0.7, carbsPer100g: 12, fatPer100g: 0.3, defaultServingG: 150),
        Entry(id: "nuts", displayName: "Mixed nuts", matchKeys: ["nut", "almond", "peanut", "walnut"], kcalPer100g: 600, proteinPer100g: 20, carbsPer100g: 20, fatPer100g: 52, defaultServingG: 40),
        Entry(id: "protein_bar", displayName: "Protein / snack bar", matchKeys: ["bar", "granola", "snack"], kcalPer100g: 400, proteinPer100g: 20, carbsPer100g: 45, fatPer100g: 14, defaultServingG: 55),
        Entry(id: "chocolate", displayName: "Chocolate / dessert", matchKeys: ["chocolate", "cake", "cookie", "dessert", "sweet", "candy", "ice cream"], kcalPer100g: 500, proteinPer100g: 6, carbsPer100g: 55, fatPer100g: 28, defaultServingG: 50),
        Entry(id: "soup", displayName: "Soup (average)", matchKeys: ["soup", "stew", "chili"], kcalPer100g: 60, proteinPer100g: 4, carbsPer100g: 8, fatPer100g: 2, defaultServingG: 350),
        Entry(id: "sushi_roll", displayName: "Sushi roll (avg)", matchKeys: ["maki", "roll"], kcalPer100g: 150, proteinPer100g: 6, carbsPer100g: 24, fatPer100g: 4, defaultServingG: 200),
        Entry(id: "fried_chicken", displayName: "Fried chicken", matchKeys: ["fried", "crispy", "nugget"], kcalPer100g: 280, proteinPer100g: 20, carbsPer100g: 12, fatPer100g: 18, defaultServingG: 180),
        Entry(id: "tofu", displayName: "Tofu", matchKeys: ["tofu", "soy", "tempeh"], kcalPer100g: 76, proteinPer100g: 8, carbsPer100g: 1.9, fatPer100g: 4.8, defaultServingG: 150),
        Entry(id: "beans", displayName: "Beans (cooked)", matchKeys: ["bean", "lentil", "chickpea", "hummus"], kcalPer100g: 120, proteinPer100g: 8, carbsPer100g: 20, fatPer100g: 1, defaultServingG: 180),
        Entry(id: "avocado", displayName: "Avocado", matchKeys: ["avocado", "guacamole"], kcalPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, defaultServingG: 100),
        Entry(id: "coffee_drink", displayName: "Coffee drink (w/ milk)", matchKeys: ["coffee", "latte", "cappuccino", "espresso"], kcalPer100g: 50, proteinPer100g: 2, carbsPer100g: 6, fatPer100g: 2, defaultServingG: 350),
        Entry(id: "smoothie", displayName: "Smoothie / shake", matchKeys: ["smoothie", "shake", "juice"], kcalPer100g: 70, proteinPer100g: 3, carbsPer100g: 14, fatPer100g: 1, defaultServingG: 400),
        Entry(id: "burger_fast", displayName: "Fast-food burger", matchKeys: ["fast food", "fastfood"], kcalPer100g: 260, proteinPer100g: 14, carbsPer100g: 24, fatPer100g: 12, defaultServingG: 220),
        Entry(id: "generic_meal", displayName: "Mixed plate (generic)", matchKeys: ["food", "meal", "dish", "plate", "lunch", "dinner", "breakfast"], kcalPer100g: 180, proteinPer100g: 10, carbsPer100g: 18, fatPer100g: 8, defaultServingG: 350),
    ]

    /// Ranks catalog entries using Vision classification identifiers and confidences.
    static func rankedEntries(visionResults: [(identifier: String, confidence: Float)]) -> [Entry] {
        var scores: [String: Float] = [:]
        for (identifier, conf) in visionResults {
            let norm = identifier.lowercased().replacingOccurrences(of: "_", with: " ")
            for entry in entries {
                for key in entry.matchKeys {
                    if norm.contains(key) || key.contains(norm) {
                        scores[entry.id, default: 0] += conf
                    }
                }
            }
        }
        return scores
            .compactMap { id, score -> (Entry, Float)? in
                guard let e = entries.first(where: { $0.id == id }) else { return nil }
                return (e, score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}
