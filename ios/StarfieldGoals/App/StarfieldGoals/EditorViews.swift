import SwiftUI

struct GoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    var goal: GoalSnapshot?
    var onSave: (String, ISODate, ISODate?, String?, String?, String?) -> Void

    @State private var title: String
    @State private var startDate: Date
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var colorHex: String
    @State private var symbolName: String
    @State private var domain: String

    private let colors = ["#FFD36A", "#8EE6FF", "#FF8A78", "#9DEB8F", "#D9B3FF"]
    private let symbols = ["star.fill", "sparkles", "book.fill", "figure.run", "paintpalette.fill", "briefcase.fill"]

    init(goal: GoalSnapshot?, onSave: @escaping (String, ISODate, ISODate?, String?, String?, String?) -> Void) {
        self.goal = goal
        self.onSave = onSave
        _title = State(initialValue: goal?.title ?? "")
        _startDate = State(initialValue: dateFromISO(goal?.startDate) ?? Date())
        _hasDueDate = State(initialValue: goal?.dueDate != nil)
        _dueDate = State(initialValue: dateFromISO(goal?.dueDate) ?? Date())
        _colorHex = State(initialValue: goal?.colorHex ?? "#FFD36A")
        _symbolName = State(initialValue: goal?.symbolName ?? "star.fill")
        _domain = State(initialValue: goal?.domain ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("目标名称", text: $title)
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                Toggle("设置完成期限", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("完成期限", selection: $dueDate, displayedComponents: .date)
                }
                Section("星图外观") {
                    Picker("颜色", selection: $colorHex) {
                        ForEach(colors, id: \.self) { value in
                            Label(value, systemImage: "circle.fill").tag(value)
                        }
                    }
                    Picker("图标", selection: $symbolName) {
                        ForEach(symbols, id: \.self) { value in
                            Label(value, systemImage: value).tag(value)
                        }
                    }
                    TextField("领域（例如 健康 / 创作 / 工作）", text: $domain)
                }
            }
            .navigationTitle(goal == nil ? "新建目标" : "编辑目标")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            title,
                            formatDate(startDate),
                            hasDueDate ? formatDate(dueDate) : nil,
                            colorHex,
                            symbolName,
                            domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : domain
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct RoutineEditor: View {
    @Environment(\.dismiss) private var dismiss
    var routine: RoutineSnapshot?
    var onSave: (String, RoutineFrequency) -> Void

    @State private var title: String
    @State private var frequencyMode: FrequencyMode
    @State private var timesPerWeek: Int

    init(routine: RoutineSnapshot?, onSave: @escaping (String, RoutineFrequency) -> Void) {
        self.routine = routine
        self.onSave = onSave
        _title = State(initialValue: routine?.title ?? "")
        switch routine?.frequency {
        case .weeklyCount(let count):
            _frequencyMode = State(initialValue: .weekly)
            _timesPerWeek = State(initialValue: count)
        default:
            _frequencyMode = State(initialValue: .daily)
            _timesPerWeek = State(initialValue: 2)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("routine 名称", text: $title)
                Picker("频率", selection: $frequencyMode) {
                    Text("每日").tag(FrequencyMode.daily)
                    Text("每周次数").tag(FrequencyMode.weekly)
                }
                .pickerStyle(.segmented)
                if frequencyMode == .weekly {
                    Stepper("每周 \(timesPerWeek) 次", value: $timesPerWeek, in: 1...7)
                }
            }
            .navigationTitle(routine == nil ? "新建 routine" : "编辑 routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            title,
                            frequencyMode == .daily ? .daily : .weeklyCount(timesPerWeek: timesPerWeek)
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private enum FrequencyMode {
        case daily
        case weekly
    }
}

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (String, ISODate?, String?, String?) -> Void

    @State private var title = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var priority = "normal"
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("事项名称", text: $title)
                Toggle("设置日期", isOn: $hasDate)
                if hasDate {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
                Picker("优先级", selection: $priority) {
                    Text("普通").tag("normal")
                    Text("重要").tag("high")
                    Text("低").tag("low")
                }
                TextField("备注", text: $notes, axis: .vertical)
            }
            .navigationTitle("新建事项")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            title,
                            hasDate ? formatDate(date) : nil,
                            priority,
                            notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private func dateFromISO(_ value: ISODate?) -> Date? {
    guard let value else {
        return nil
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let parts = value.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else {
        return nil
    }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}
