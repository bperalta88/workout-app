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
        let barcode: String?

        init(
            id: String,
            displayName: String,
            matchKeys: [String],
            kcalPer100g: Double,
            proteinPer100g: Double,
            carbsPer100g: Double,
            fatPer100g: Double,
            defaultServingG: Double,
            barcode: String? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.matchKeys = matchKeys
            self.kcalPer100g = kcalPer100g
            self.proteinPer100g = proteinPer100g
            self.carbsPer100g = carbsPer100g
            self.fatPer100g = fatPer100g
            self.defaultServingG = defaultServingG
            self.barcode = barcode
        }

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

    static func entry(matchingBarcode barcode: String) -> Entry? {
        let clean = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return entries.first { $0.barcode == clean }
    }

    static let entries: [Entry] = [
        // Branded quick picks (especially for bars/shakes) so logs can be specific.
        Entry(id: "quest_bar_cookie_dough", displayName: "Quest Protein Bar - Chocolate Chip Cookie Dough (60g)", matchKeys: ["quest", "quest bar", "chocolate chip cookie dough", "protein bar"], kcalPer100g: 333, proteinPer100g: 33.3, carbsPer100g: 35, fatPer100g: 11.7, defaultServingG: 60),
        Entry(id: "quest_bar_cookies_cream", displayName: "Quest Protein Bar - Cookies & Cream (60g)", matchKeys: ["quest", "quest bar", "cookies and cream", "cookies & cream", "protein bar"], kcalPer100g: 317, proteinPer100g: 35, carbsPer100g: 33.3, fatPer100g: 11.7, defaultServingG: 60),
        Entry(id: "quest_bar_choc_pb", displayName: "Quest Protein Bar - Chocolate Peanut Butter (60g)", matchKeys: ["quest", "quest bar", "chocolate peanut butter", "protein bar"], kcalPer100g: 333, proteinPer100g: 33.3, carbsPer100g: 35, fatPer100g: 13.3, defaultServingG: 60),
        Entry(id: "quest_chips_nacho", displayName: "Quest Protein Chips - Nacho Cheese (32g)", matchKeys: ["quest chips", "quest", "nacho", "protein chips"], kcalPer100g: 469, proteinPer100g: 59.4, carbsPer100g: 15.6, fatPer100g: 15.6, defaultServingG: 32),
        Entry(id: "quest_chips_ranch", displayName: "Quest Protein Chips - Ranch (32g)", matchKeys: ["quest chips", "quest", "ranch", "protein chips"], kcalPer100g: 469, proteinPer100g: 59.4, carbsPer100g: 15.6, fatPer100g: 15.6, defaultServingG: 32),
        Entry(id: "kirkland_bar_cookie_dough", displayName: "Kirkland Protein Bar - Cookie Dough (60g)", matchKeys: ["kirkland", "costco", "kirkland bar", "cookie dough", "protein bar"], kcalPer100g: 317, proteinPer100g: 35, carbsPer100g: 38.3, fatPer100g: 13.3, defaultServingG: 60),
        Entry(id: "kirkland_bar_brownie", displayName: "Kirkland Protein Bar - Chocolate Brownie (60g)", matchKeys: ["kirkland", "costco", "kirkland bar", "brownie", "protein bar"], kcalPer100g: 317, proteinPer100g: 35, carbsPer100g: 38.3, fatPer100g: 13.3, defaultServingG: 60),
        Entry(id: "kirkland_shake_chocolate", displayName: "Kirkland Protein Shake - Chocolate (325ml)", matchKeys: ["kirkland shake", "costco shake", "kirkland", "protein shake"], kcalPer100g: 49, proteinPer100g: 9.2, carbsPer100g: 1.8, fatPer100g: 0.9, defaultServingG: 325),
        Entry(id: "built_bar_coconut", displayName: "Built Bar - Coconut (46g)", matchKeys: ["built", "built bar", "coconut", "protein bar"], kcalPer100g: 283, proteinPer100g: 37, carbsPer100g: 34.8, fatPer100g: 10.9, defaultServingG: 46),
        Entry(id: "built_puff_cookie_dough", displayName: "Built Puff - Chocolate Chip Cookie Dough (40g)", matchKeys: ["built puff", "built", "cookie dough puff", "protein bar"], kcalPer100g: 350, proteinPer100g: 42.5, carbsPer100g: 37.5, fatPer100g: 12.5, defaultServingG: 40),
        Entry(id: "one_bar_pb_pie", displayName: "ONE Protein Bar - Peanut Butter Pie (60g)", matchKeys: ["one bar", "one protein bar", "peanut butter pie", "protein bar"], kcalPer100g: 383, proteinPer100g: 33.3, carbsPer100g: 28.3, fatPer100g: 13.3, defaultServingG: 60),
        Entry(id: "rxbar_choc_seasalt", displayName: "RXBAR - Chocolate Sea Salt (52g)", matchKeys: ["rxbar", "rx bar", "chocolate sea salt", "protein bar"], kcalPer100g: 404, proteinPer100g: 23.1, carbsPer100g: 44.2, fatPer100g: 17.3, defaultServingG: 52),
        Entry(id: "think_bar_brownie", displayName: "think! Protein Bar - Brownie Crunch (60g)", matchKeys: ["think bar", "think!", "brownie crunch", "protein bar"], kcalPer100g: 383, proteinPer100g: 33.3, carbsPer100g: 30, fatPer100g: 15, defaultServingG: 60),
        Entry(id: "fairlife_shake_chocolate", displayName: "Fairlife Core Power 26g - Chocolate (414ml)", matchKeys: ["fairlife", "core power", "protein shake", "chocolate shake"], kcalPer100g: 63, proteinPer100g: 6.3, carbsPer100g: 3.9, fatPer100g: 2.9, defaultServingG: 414),
        Entry(id: "fairlife_nutrition_plan", displayName: "Fairlife Nutrition Plan - Chocolate (340ml)", matchKeys: ["fairlife nutrition plan", "fairlife", "costco fairlife", "protein shake"], kcalPer100g: 44, proteinPer100g: 8.8, carbsPer100g: 2.6, fatPer100g: 0.8, defaultServingG: 340),
        Entry(id: "premier_protein_chocolate", displayName: "Premier Protein Shake - Chocolate (325ml)", matchKeys: ["premier", "premier protein", "protein shake", "chocolate shake"], kcalPer100g: 49, proteinPer100g: 9.2, carbsPer100g: 1.5, fatPer100g: 0.9, defaultServingG: 325),
        Entry(id: "muscle_milk_pro", displayName: "Muscle Milk Pro Series - Knockout Chocolate (414ml)", matchKeys: ["muscle milk", "muscle milk pro", "protein shake"], kcalPer100g: 47, proteinPer100g: 7.2, carbsPer100g: 3.4, fatPer100g: 0.7, defaultServingG: 414),
        Entry(id: "ghost_whey_scoop", displayName: "Ghost Whey Protein - 1 scoop (39g)", matchKeys: ["ghost whey", "ghost protein", "whey scoop", "protein powder"], kcalPer100g: 333, proteinPer100g: 64.1, carbsPer100g: 15.4, fatPer100g: 5.1, defaultServingG: 39),
        Entry(id: "optimum_whey_scoop", displayName: "Optimum Nutrition Gold Standard - 1 scoop (31g)", matchKeys: ["optimum", "on whey", "gold standard", "whey scoop", "protein powder"], kcalPer100g: 387, proteinPer100g: 77.4, carbsPer100g: 9.7, fatPer100g: 3.2, defaultServingG: 31),
        Entry(id: "oikos_pro_yogurt_vanilla", displayName: "Oikos Pro Yogurt - Vanilla (150g)", matchKeys: ["oikos", "oikos pro", "greek yogurt", "yogurt"], kcalPer100g: 67, proteinPer100g: 13.3, carbsPer100g: 4.7, fatPer100g: 0, defaultServingG: 150),
        Entry(id: "chobani_zero_sugar", displayName: "Chobani Zero Sugar Yogurt (150g)", matchKeys: ["chobani", "zero sugar yogurt", "greek yogurt", "yogurt"], kcalPer100g: 40, proteinPer100g: 7.3, carbsPer100g: 4, fatPer100g: 0, defaultServingG: 150),
        Entry(id: "ratio_protein_yogurt", displayName: "Ratio Protein Yogurt - Vanilla (150g)", matchKeys: ["ratio yogurt", "ratio protein", "protein yogurt", "yogurt"], kcalPer100g: 80, proteinPer100g: 16.7, carbsPer100g: 5.3, fatPer100g: 1.3, defaultServingG: 150),
        Entry(id: "dave_bread_thin", displayName: "Dave's Killer Bread - Thin Sliced 21 Whole Grains (54g)", matchKeys: ["dave's killer bread", "daves bread", "thin sliced bread", "bread"], kcalPer100g: 204, proteinPer100g: 14.8, carbsPer100g: 37, fatPer100g: 3.7, defaultServingG: 54),
        Entry(id: "ezekiel_bread", displayName: "Ezekiel 4:9 Bread - 2 slices (68g)", matchKeys: ["ezekiel", "sprouted bread", "bread"], kcalPer100g: 235, proteinPer100g: 14.7, carbsPer100g: 43.1, fatPer100g: 1.5, defaultServingG: 68),
        Entry(id: "eggo_waffles", displayName: "Eggo Waffles - Homestyle (70g)", matchKeys: ["eggo", "waffles", "breakfast waffles"], kcalPer100g: 386, proteinPer100g: 8.6, carbsPer100g: 48.6, fatPer100g: 17.1, defaultServingG: 70),
        Entry(id: "cheerios", displayName: "Cheerios - Original (39g)", matchKeys: ["cheerios", "cereal"], kcalPer100g: 359, proteinPer100g: 20.5, carbsPer100g: 74.4, fatPer100g: 5.1, defaultServingG: 39),
        Entry(id: "honey_nut_cheerios", displayName: "Honey Nut Cheerios (39g)", matchKeys: ["honey nut cheerios", "cheerios", "cereal"], kcalPer100g: 385, proteinPer100g: 15.4, carbsPer100g: 76.9, fatPer100g: 7.7, defaultServingG: 39),
        Entry(id: "chipotle_bowl_chicken", displayName: "Chipotle Chicken Burrito Bowl (600g est)", matchKeys: ["chipotle", "chipotle bowl", "burrito bowl", "chicken bowl"], kcalPer100g: 167, proteinPer100g: 11.7, carbsPer100g: 15, fatPer100g: 6.7, defaultServingG: 600),
        Entry(id: "chickfila_sandwich", displayName: "Chick-fil-A Chicken Sandwich (183g)", matchKeys: ["chick-fil-a", "chickfila", "chicken sandwich"], kcalPer100g: 241, proteinPer100g: 15.8, carbsPer100g: 22.4, fatPer100g: 10.9, defaultServingG: 183),
        Entry(id: "innout_double_double", displayName: "In-N-Out Double-Double (330g est)", matchKeys: ["in n out", "in-n-out", "double double", "burger"], kcalPer100g: 203, proteinPer100g: 11.5, carbsPer100g: 9.4, fatPer100g: 13.9, defaultServingG: 330),
        Entry(id: "mcd_double_cheese", displayName: "McDonald's Double Cheeseburger (161g)", matchKeys: ["mcdonald", "double cheeseburger", "mcd"], kcalPer100g: 273, proteinPer100g: 15.5, carbsPer100g: 20.5, fatPer100g: 15.5, defaultServingG: 161),
        Entry(id: "starbucks_egg_bites", displayName: "Starbucks Egg White & Roasted Red Pepper Bites (130g)", matchKeys: ["starbucks egg bites", "egg white bites", "starbucks"], kcalPer100g: 131, proteinPer100g: 13.8, carbsPer100g: 8.5, fatPer100g: 4.6, defaultServingG: 130),
        Entry(id: "gatorade_zero", displayName: "Gatorade Zero - Lemon Lime (591ml)", matchKeys: ["gatorade zero", "sports drink", "electrolyte"], kcalPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, defaultServingG: 591),
        Entry(id: "coke_zero", displayName: "Coke Zero (355ml)", matchKeys: ["coke zero", "zero soda", "diet soda"], kcalPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, defaultServingG: 355),

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
        Entry(id: "protein_bar", displayName: "Protein / snack bar (generic)", matchKeys: ["bar", "granola", "snack"], kcalPer100g: 400, proteinPer100g: 20, carbsPer100g: 45, fatPer100g: 14, defaultServingG: 55),
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
