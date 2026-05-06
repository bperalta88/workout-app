import SwiftUI
import SwiftData
import PhotosUI

struct NutritionTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealLog.loggedAt, order: .reverse) private var mealLogs: [MealLog]

    @AppStorage("nutritionDailyCalorieGoal") private var calorieGoal = 2200
    @AppStorage("nutritionDailyProteinGoal") private var proteinGoal = 170
    @AppStorage("nutritionDailyCarbsGoal") private var carbsGoal = 220
    @AppStorage("nutritionDailyFatGoal") private var fatGoal = 70

    @State private var showAddMeal = false
    @State private var showGoalsSheet = false
    @State private var selectedMeal: MealLog?

    private let calendar = Calendar.current

    private var todayStart: Date { calendar.startOfDay(for: Date()) }

    private var todaysMeals: [MealLog] {
        mealLogs.filter { $0.loggedAt >= todayStart }
    }

    private var todayTotals: (cal: Double, p: Double, c: Double, f: Double) {
        todaysMeals.reduce(into: (0, 0, 0, 0)) { acc, m in
            acc.0 += m.calories
            acc.1 += m.proteinG
            acc.2 += m.carbsG
            acc.3 += m.fatG
        }
    }

    private var groupedMeals: [(day: Date, items: [MealLog])] {
        let groups = Dictionary(grouping: mealLogs) { calendar.startOfDay(for: $0.loggedAt) }
        return groups.keys.sorted(by: >).map { day in
            let items = (groups[day] ?? []).sorted { $0.loggedAt > $1.loggedAt }
            return (day, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                todaySummaryCard
                disclaimerNote
                mealsSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 110)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        showGoalsSheet = true
                    } label: {
                        Image(systemName: "target")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("Daily goals")

                    Button {
                        showAddMeal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .accessibilityLabel("Log meal")
                }
                .foregroundStyle(AppTheme.primaryBlue)
            }
        }
        .sheet(isPresented: $showAddMeal) {
            AddMealSheet()
        }
        .sheet(isPresented: $showGoalsSheet) {
            NutritionGoalsSheet(
                calorieGoal: $calorieGoal,
                proteinGoal: $proteinGoal,
                carbsGoal: $carbsGoal,
                fatGoal: $fatGoal
            )
        }
        .sheet(item: $selectedMeal) { meal in
            MealDetailSheet(meal: meal)
        }
    }

    private var todaySummaryCard: some View {
        let t = todayTotals
        let cg = max(1, calorieGoal)
        let pg = max(1, proteinGoal)
        let carbG = max(1, carbsGoal)
        let fg = max(1, fatGoal)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.titleText)
                Spacer()
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }

            HStack(spacing: 10) {
                macroRing(title: "Cal", value: t.cal, goal: Double(cg), color: AppTheme.primaryBlue)
                macroRing(title: "Protein", value: t.p, goal: Double(pg), color: AppTheme.accentLime)
                macroRing(title: "Carbs", value: t.c, goal: Double(carbG), color: Color.orange)
                macroRing(title: "Fat", value: t.f, goal: Double(fg), color: Color.pink)
            }

            HStack(spacing: 8) {
                Label("\(Int(t.cal)) / \(calorieGoal) kcal", systemImage: "flame.fill")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.bodyText)
                Spacer()
                Text("P \(Int(t.p)) • C \(Int(t.c)) • F \(Int(t.f)) g")
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .padding(14)
        .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
    }

    private func macroRing(title: String, value: Double, goal: Double, color: Color) -> some View {
        let progress = min(1.1, value / goal)
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(AppTheme.subtleFill, lineWidth: 5)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: min(1, progress))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                Text(shortMacroValue(value))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.titleText)
            }
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortMacroValue(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return "\(Int(v.rounded()))"
    }

    private var disclaimerNote: some View {
        Text("Meal photos: free on-device matching by default, or optional OpenAI (GPT-4o) if you add a key. Browse uses the same local food list. Estimates only—not medical advice.")
            .font(.system(.caption2, design: .default, weight: .medium))
            .foregroundStyle(AppTheme.mutedText)
            .padding(.horizontal, 4)
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Log")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.titleText)

            if groupedMeals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(AppTheme.primaryBlue)
                    Text("No meals logged")
                        .font(.system(.body, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.titleText)
                    Text("Tap + for quick entry, browse foods, or a photo analyzed with GPT-4o.")
                        .font(.system(.subheadline, design: .default, weight: .regular))
                        .foregroundStyle(AppTheme.bodyText)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .minimalCard(cornerRadius: AppTheme.cardCornerRadius)
            } else {
                ForEach(groupedMeals, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sectionTitle(for: group.day))
                            .font(.system(.caption, design: .default, weight: .bold))
                            .foregroundStyle(AppTheme.mutedText)
                            .padding(.leading, 2)

                        ForEach(group.items, id: \.persistentModelID) { meal in
                            Button {
                                selectedMeal = meal
                            } label: {
                                mealRow(meal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(for day: Date) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private func mealRow(_ meal: MealLog) -> some View {
        HStack(spacing: 12) {
            if let data = meal.photoJPEG, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.subtleFill)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: meal.resolvedSlot.icon)
                            .foregroundStyle(AppTheme.primaryBlue)
                    }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(meal.name)
                        .font(.system(.body, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.titleText)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text("\(Int(meal.calories)) kcal")
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                }
                Text("\(meal.resolvedSlot.label) • \(meal.loggedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.mutedText)
                Text("P \(Int(meal.proteinG))g  •  C \(Int(meal.carbsG))g  •  F \(Int(meal.fatG))g")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(AppTheme.bodyText)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText.opacity(0.7))
        }
        .padding(12)
        .minimalCard(cornerRadius: 14)
    }
}

// MARK: - Goals

private struct NutritionGoalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var calorieGoal: Int
    @Binding var proteinGoal: Int
    @Binding var carbsGoal: Int
    @Binding var fatGoal: Int

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily targets") {
                    Stepper("Calories: \(calorieGoal)", value: $calorieGoal, in: 1200...6000, step: 50)
                    Stepper("Protein: \(proteinGoal) g", value: $proteinGoal, in: 40...400, step: 5)
                    Stepper("Carbs: \(carbsGoal) g", value: $carbsGoal, in: 50...600, step: 5)
                    Stepper("Fat: \(fatGoal) g", value: $fatGoal, in: 30...200, step: 5)
                }
            }
            .navigationTitle("Nutrition goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add meal

private enum MealPhotoAnalysisKind: String, CaseIterable, Identifiable {
    case onDevice
    case openAI

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .onDevice: return "On-device (free)"
        case .openAI: return "OpenAI"
        }
    }
}

/// One row from GPT-4o; macros scale when the user edits grams.
private struct PhotoLineItem: Identifiable {
    let id: UUID
    let name: String
    let baselineGrams: Double
    var currentGrams: Double
    let calAtBaseline: Double
    let proteinAtBaseline: Double
    let carbsAtBaseline: Double
    let fatAtBaseline: Double

    var scale: Double { currentGrams / max(baselineGrams, 1) }
    var calories: Double { calAtBaseline * scale }
    var proteinG: Double { proteinAtBaseline * scale }
    var carbsG: Double { carbsAtBaseline * scale }
    var fatG: Double { fatAtBaseline * scale }

    init(row: MealVisionItemRow) {
        id = UUID()
        name = row.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Food item" : row.name
        let g = max(10, row.estimatedGrams)
        baselineGrams = g
        currentGrams = g
        calAtBaseline = max(0, row.calories)
        proteinAtBaseline = max(0, row.proteinG)
        carbsAtBaseline = max(0, row.carbsG)
        fatAtBaseline = max(0, row.fatG)
    }
}

private struct AddMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum AddMode: String, CaseIterable {
        case quick = "Quick"
        case photo = "Photo"
        case browse = "Browse"
    }

    @State private var mode: AddMode = .quick
    @State private var slot: MealSlot = .lunch
    @State private var mealName = ""

    @State private var quickCal = ""
    @State private var quickP = ""
    @State private var quickC = ""
    @State private var quickF = ""

    @AppStorage("openAIMealAPIKey") private var openAIAPIKey = ""
    @AppStorage("mealPhotoAnalysisKind") private var mealPhotoAnalysisKindRaw = MealPhotoAnalysisKind.onDevice.rawValue

    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var isAnalyzing = false
    @State private var photoLineItems: [PhotoLineItem] = []
    @State private var aiMealTitle: String?
    @State private var photoError: String?

    @State private var onDeviceRankedEntries: [LocalFoodCatalog.Entry] = []
    @State private var onDeviceServingById: [String: Double] = [:]
    @State private var onDeviceLabelSummary: String = ""

    private var mealPhotoAnalysisKind: MealPhotoAnalysisKind {
        MealPhotoAnalysisKind(rawValue: mealPhotoAnalysisKindRaw) ?? .onDevice
    }

    @State private var browseQuery = ""
    @State private var browseSelections: [String: Double] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(AddMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                Form {
                    Section {
                        Picker("Meal", selection: $slot) {
                            ForEach(MealSlot.allCases) { s in
                                Label(s.label, systemImage: s.icon).tag(s)
                            }
                        }
                        TextField("Name (optional)", text: $mealName)
                    }

                    switch mode {
                    case .quick:
                        quickSection
                    case .photo:
                        photoSection
                    case .browse:
                        browseSection
                    }
                }
            }
            .navigationTitle("Log meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveMeal() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, new in
                Task { await loadAndAnalyzePhoto(new) }
            }
            .onChange(of: openAIAPIKey) { oldValue, newValue in
                guard mealPhotoAnalysisKind == .openAI else { return }
                let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let nowHasKey = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                guard mode == .photo, wasEmpty, nowHasKey, let img = photoImage, !isAnalyzing else { return }
                guard photoLineItems.isEmpty else { return }
                Task { await analyzePhoto(img) }
            }
            .onChange(of: mealPhotoAnalysisKindRaw) { _, _ in
                guard mode == .photo, let img = photoImage else { return }
                Task { await runPhotoAnalysis(for: img) }
            }
        }
    }

    private var quickSection: some View {
        Section("Macros") {
            TextField("Calories", text: $quickCal)
                .keyboardType(.numberPad)
            TextField("Protein (g)", text: $quickP)
                .keyboardType(.decimalPad)
            TextField("Carbs (g)", text: $quickC)
                .keyboardType(.decimalPad)
            TextField("Fat (g)", text: $quickF)
                .keyboardType(.decimalPad)
        }
    }

    private var photoSection: some View {
        Section {
            Picker("Analysis", selection: $mealPhotoAnalysisKindRaw) {
                ForEach(MealPhotoAnalysisKind.allCases) { kind in
                    Text(kind.pickerLabel).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if mealPhotoAnalysisKind == .onDevice {
                Text("Runs entirely on your iPhone: Vision labels are matched to a local food list. Toggle items and adjust grams—no account or API key.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.bodyText)
            } else {
                Text("Uses OpenAI GPT-4o (paid API). Paste your secret key here or in Settings → Meal photos (AI).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.bodyText)
                SecureField("OpenAI API key (sk-…)", text: $openAIAPIKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Text("After pasting, analysis can run automatically when the key is saved.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoImage == nil ? "Choose meal photo" : "Replace photo", systemImage: "photo.on.rectangle.angled")
            }

            if isAnalyzing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(mealPhotoAnalysisKind == .onDevice ? "Matching foods on-device…" : "Analyzing with GPT-4o…")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedText)
                }
            }

            if let photoError {
                Text(photoError)
                    .font(.subheadline)
                    .foregroundStyle(.red.opacity(0.9))
                if photoImage != nil {
                    Button("Try again") {
                        Task {
                            if let photoImage { await runPhotoAnalysis(for: photoImage) }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            if let photoImage {
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if mealPhotoAnalysisKind == .onDevice, !onDeviceLabelSummary.isEmpty {
                Text("Labels: \(onDeviceLabelSummary)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedText)
            }

            let totals = photoMacroTotals
            if totals.cal > 0 || totals.p > 0 || totals.c > 0 || totals.f > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meal totals (adjust grams below)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText)
                    Text("\(Int(totals.cal)) kcal  •  P \(Int(totals.p))g  •  C \(Int(totals.c))g  •  F \(Int(totals.f))g")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.titleText)
                }
                .padding(.vertical, 4)
            }

            if mealPhotoAnalysisKind == .openAI, !photoLineItems.isEmpty {
                ForEach($photoLineItems) { $line in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(line.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.titleText)
                        HStack {
                            Text("Portion")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedText)
                            Slider(value: $line.currentGrams, in: 10...800, step: 5)
                            Text("\(Int(line.currentGrams)) g")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.bodyText)
                                .frame(width: 56, alignment: .trailing)
                        }
                        Text("\(Int(line.calories)) kcal • P \(Int(line.proteinG)) • C \(Int(line.carbsG)) • F \(Int(line.fatG))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    .padding(.vertical, 6)
                }
            }

            if mealPhotoAnalysisKind == .onDevice, !onDeviceRankedEntries.isEmpty {
                ForEach(onDeviceRankedEntries.prefix(12)) { entry in
                    let grams = bindingServing(for: entry.id, defaultG: entry.defaultServingG, dict: $onDeviceServingById)
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: Binding(
                            get: { grams.wrappedValue > 0 },
                            set: { on in
                                grams.wrappedValue = on ? entry.defaultServingG : 0
                            }
                        )) {
                            Text(entry.displayName)
                                .font(.subheadline.weight(.semibold))
                        }
                        if grams.wrappedValue > 0 {
                            HStack {
                                Text("Serving")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mutedText)
                                Slider(value: grams, in: 20...500, step: 10)
                                Text("\(Int(grams.wrappedValue)) g")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(AppTheme.bodyText)
                                    .frame(width: 52, alignment: .trailing)
                            }
                            let m = entry.macros(forServingGrams: grams.wrappedValue)
                            Text("\(Int(m.cal)) kcal • P \(Int(m.p)) • C \(Int(m.c)) • F \(Int(m.f))")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppTheme.mutedText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var photoMacroTotals: (cal: Double, p: Double, c: Double, f: Double) {
        switch mealPhotoAnalysisKind {
        case .onDevice:
            return onDeviceRankedEntries.reduce(into: (0, 0, 0, 0)) { acc, entry in
                let g = onDeviceServingById[entry.id] ?? 0
                guard g > 0 else { return }
                let m = entry.macros(forServingGrams: g)
                acc.0 += m.cal; acc.1 += m.p; acc.2 += m.c; acc.3 += m.f
            }
        case .openAI:
            return photoLineItems.reduce(into: (0, 0, 0, 0)) { acc, line in
                acc.0 += line.calories
                acc.1 += line.proteinG
                acc.2 += line.carbsG
                acc.3 += line.fatG
            }
        }
    }

    private var browseSection: some View {
        Section {
            TextField("Search foods", text: $browseQuery)
                .textInputAutocapitalization(.never)

            let filtered = LocalFoodCatalog.entries.filter { entry in
                browseQuery.isEmpty
                    || entry.displayName.localizedCaseInsensitiveContains(browseQuery)
                    || entry.matchKeys.contains { $0.localizedCaseInsensitiveContains(browseQuery) }
            }

            ForEach(filtered) { entry in
                let grams = bindingServing(for: entry.id, defaultG: 0, dict: $browseSelections)
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: Binding(
                        get: { grams.wrappedValue > 0 },
                        set: { on in
                            grams.wrappedValue = on ? entry.defaultServingG : 0
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text("~\(Int(entry.kcalPer100g)) kcal / 100 g")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                    }
                    if grams.wrappedValue > 0 {
                        HStack {
                            Text("Serving")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedText)
                            Slider(value: grams, in: 20...500, step: 10)
                            Text("\(Int(grams.wrappedValue)) g")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.bodyText)
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func bindingServing(for id: String, defaultG: Double, dict: Binding<[String: Double]>) -> Binding<Double> {
        Binding(
            get: { dict.wrappedValue[id] ?? 0 },
            set: { dict.wrappedValue[id] = $0 }
        )
    }

    private var canSave: Bool {
        switch mode {
        case .quick:
            let cal = Double(quickCal) ?? 0
            let p = Double(quickP) ?? 0
            let c = Double(quickC) ?? 0
            let f = Double(quickF) ?? 0
            return cal > 0 || p > 0 || c > 0 || f > 0
        case .photo, .browse:
            return totalFromSelections() > 0
        }
    }

    private func totalFromSelections() -> Double {
        var cal: Double = 0
        switch mode {
        case .photo:
            let t = photoMacroTotals
            cal = t.cal
        case .browse:
            for entry in LocalFoodCatalog.entries {
                let g = browseSelections[entry.id] ?? 0
                if g > 0 {
                    cal += entry.macros(forServingGrams: g).cal
                }
            }
        default: break
        }
        return cal
    }

    private func aggregateMacros() -> (cal: Double, p: Double, c: Double, f: Double) {
        var cal: Double = 0, p: Double = 0, c: Double = 0, f: Double = 0
        switch mode {
        case .quick:
            cal = Double(quickCal) ?? 0
            p = Double(quickP) ?? 0
            c = Double(quickC) ?? 0
            f = Double(quickF) ?? 0
        case .photo:
            let t = photoMacroTotals
            cal = t.cal; p = t.p; c = t.c; f = t.f
        case .browse:
            for entry in LocalFoodCatalog.entries {
                let g = browseSelections[entry.id] ?? 0
                guard g > 0 else { continue }
                let m = entry.macros(forServingGrams: g)
                cal += m.cal; p += m.p; c += m.c; f += m.f
            }
        }
        return (cal, p, c, f)
    }

    private func defaultMealName(macros: (cal: Double, p: Double, c: Double, f: Double)) -> String {
        if !mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        switch mode {
        case .quick:
            return slot.label
        case .photo:
            switch mealPhotoAnalysisKind {
            case .openAI:
                if let t = aiMealTitle, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
                let names = photoLineItems.map(\.name)
                if names.isEmpty { return "Meal (photo)" }
                if names.count <= 2 { return names.joined(separator: " + ") }
                return "\(names.prefix(2).joined(separator: " + ")) + \(names.count - 2) more"
            case .onDevice:
                let names = onDeviceRankedEntries.compactMap { e -> String? in
                    guard (onDeviceServingById[e.id] ?? 0) > 0 else { return nil }
                    return e.displayName
                }
                if names.isEmpty { return "Meal (photo)" }
                if names.count <= 2 { return names.joined(separator: " + ") }
                return "\(names.prefix(2).joined(separator: " + ")) + \(names.count - 2) more"
            }
        case .browse:
            let names = LocalFoodCatalog.entries.compactMap { e -> String? in
                guard (browseSelections[e.id] ?? 0) > 0 else { return nil }
                return e.displayName
            }
            if names.isEmpty { return slot.label }
            if names.count <= 2 { return names.joined(separator: " + ") }
            return "\(names.prefix(2).joined(separator: " + ")) + \(names.count - 2) more"
        }
    }

    private func jpegPayload(from image: UIImage?) -> Data? {
        guard let image else { return nil }
        let maxSide: CGFloat = 1200
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: 0.55)
    }

    private func saveMeal() {
        let macros = aggregateMacros()
        let name = defaultMealName(macros: macros)
        let photoData = (mode == .photo) ? jpegPayload(from: photoImage) : nil
        let usedEstimate: Bool = {
            guard mode == .photo, photoImage != nil else { return false }
            switch mealPhotoAnalysisKind {
            case .openAI: return !photoLineItems.isEmpty
            case .onDevice:
                return onDeviceRankedEntries.contains { (onDeviceServingById[$0.id] ?? 0) > 0 }
            }
        }()
        let visionSummary: String = {
            guard mode == .photo else { return "" }
            switch mealPhotoAnalysisKind {
            case .openAI:
                guard !photoLineItems.isEmpty else { return "" }
                let lines = photoLineItems.map { "\($0.name): \(Int($0.currentGrams))g (~\(Int($0.calories)) kcal)" }
                return "GPT-4o — " + lines.joined(separator: "; ")
            case .onDevice:
                let lines = onDeviceRankedEntries.compactMap { e -> String? in
                    let g = onDeviceServingById[e.id] ?? 0
                    guard g > 0 else { return nil }
                    let m = e.macros(forServingGrams: g)
                    return "\(e.displayName): \(Int(g))g (~\(Int(m.cal)) kcal)"
                }
                guard !lines.isEmpty else { return "" }
                let labelNote = onDeviceLabelSummary.isEmpty ? "" : " Labels: \(onDeviceLabelSummary)."
                return "On-device — " + lines.joined(separator: "; ") + labelNote
            }
        }()
        let log = MealLog(
            slot: slot,
            name: name,
            calories: max(0, macros.cal),
            proteinG: max(0, macros.p),
            carbsG: max(0, macros.c),
            fatG: max(0, macros.f),
            notes: "",
            photoJPEG: photoData,
            usedPhotoEstimate: usedEstimate,
            visionSummary: visionSummary
        )
        modelContext.insert(log)
        try? modelContext.save()
        dismiss()
    }

    private func loadAndAnalyzePhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else { return }
        await MainActor.run {
            photoImage = ui
            photoLineItems = []
            aiMealTitle = nil
            photoError = nil
            onDeviceRankedEntries = []
            onDeviceServingById = [:]
            onDeviceLabelSummary = ""
        }
        await runPhotoAnalysis(for: ui)
    }

    private func runPhotoAnalysis(for image: UIImage) async {
        let kind = await MainActor.run { mealPhotoAnalysisKind }
        switch kind {
        case .onDevice:
            await analyzeOnDevice(image)
        case .openAI:
            await analyzePhoto(image)
        }
    }

    private func analyzeOnDevice(_ image: UIImage) async {
        await MainActor.run {
            isAnalyzing = true
            photoError = nil
            photoLineItems = []
            aiMealTitle = nil
        }
        do {
            let (entries, summary) = try await OnDeviceMealPhotoAnalyzer.suggestCatalogEntries(from: image)
            await MainActor.run {
                onDeviceRankedEntries = entries
                onDeviceLabelSummary = summary
                onDeviceServingById = [:]
                for e in entries.prefix(4) {
                    onDeviceServingById[e.id] = e.defaultServingG
                }
                isAnalyzing = false
                photoError = entries.isEmpty
                    ? "No foods matched on-device labels. Try OpenAI mode, Browse, or Quick."
                    : nil
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
                onDeviceRankedEntries = []
                onDeviceServingById = [:]
                onDeviceLabelSummary = ""
                photoError = "On-device analysis failed: \(error.localizedDescription)"
            }
        }
    }

    private func analyzePhoto(_ image: UIImage) async {
        let key = await MainActor.run { openAIAPIKey }
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                photoError = MealEstimationError.missingAPIKey.localizedDescription
                photoLineItems = []
                aiMealTitle = nil
                onDeviceRankedEntries = []
                onDeviceServingById = [:]
                onDeviceLabelSummary = ""
            }
            return
        }

        await MainActor.run {
            isAnalyzing = true
            photoError = nil
            onDeviceRankedEntries = []
            onDeviceServingById = [:]
            onDeviceLabelSummary = ""
        }

        do {
            let payload = try await MealEstimationService.estimateMealFromPhoto(image: image, apiKey: key)
            await MainActor.run {
                aiMealTitle = payload.mealName
                photoLineItems = payload.items.map { PhotoLineItem(row: $0) }
                isAnalyzing = false
                photoError = nil
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
                photoLineItems = []
                aiMealTitle = nil
                photoError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Detail

private struct MealDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var meal: MealLog

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let data = meal.photoJPEG, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(meal.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.titleText)
                        Text("\(meal.resolvedSlot.label) • \(meal.loggedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    HStack(spacing: 12) {
                        macroTile("Calories", "\(Int(meal.calories))", "kcal")
                        macroTile("Protein", "\(Int(meal.proteinG))", "g")
                        macroTile("Carbs", "\(Int(meal.carbsG))", "g")
                        macroTile("Fat", "\(Int(meal.fatG))", "g")
                    }

                    if meal.usedPhotoEstimate, !meal.visionSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AI estimate")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedText)
                            Text(meal.visionSummary)
                                .font(.caption)
                                .foregroundStyle(AppTheme.bodyText)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .minimalCard(cornerRadius: 12)
                    }
                }
                .padding(18)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        modelContext.delete(meal)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private func macroTile(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.titleText)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .minimalCard(cornerRadius: 12)
    }
}
