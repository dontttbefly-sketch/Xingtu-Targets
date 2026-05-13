import StarfieldGoalsCore
import SwiftUI

private enum QuickCaptureMode: String, CaseIterable, Identifiable {
    case goal = "恒星"
    case routine = "轨道"
    case task = "事项"

    var id: String { rawValue }
}

struct QuickCaptureView: View {
    var goals: [Goal]
    var onCreateGoal: (String, ISODate, ISODate?) -> Void
    var onCreateRoutine: (String, String, RoutineFrequency) -> Void
    var onCreateTask: (String, String, ISODate?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: QuickCaptureMode = .goal
    @State private var title = ""
    @State private var selectedGoalId: String
    @State private var startDate = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var isWeekly = false
    @State private var timesPerWeek = 2
    @State private var hasTaskDate = false
    @State private var taskDate = Date()

    init(
        goals: [Goal],
        onCreateGoal: @escaping (String, ISODate, ISODate?) -> Void,
        onCreateRoutine: @escaping (String, String, RoutineFrequency) -> Void,
        onCreateTask: @escaping (String, String, ISODate?) -> Void
    ) {
        self.goals = goals
        self.onCreateGoal = onCreateGoal
        self.onCreateRoutine = onCreateRoutine
        self.onCreateTask = onCreateTask
        _selectedGoalId = State(initialValue: goals.first?.id ?? "")
    }

    private var selectedGoalExists: Bool {
        goals.contains { $0.id == selectedGoalId }
    }

    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return false
        }
        switch mode {
        case .goal:
            return true
        case .routine, .task:
            return selectedGoalExists
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("快速捕获")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("先把想法放进星图，再慢慢雕刻细节。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Picker("类型", selection: $mode) {
                ForEach(QuickCaptureMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextField(placeholder, text: $title)
                .textFieldStyle(.roundedBorder)

            switch mode {
            case .goal:
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                Toggle("设置完成期限", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("完成期限", selection: $dueDate, displayedComponents: .date)
                }

            case .routine:
                goalPicker
                Picker("频率", selection: $isWeekly) {
                    Text("每日").tag(false)
                    Text("每周 N 次").tag(true)
                }
                .pickerStyle(.segmented)
                if isWeekly {
                    Stepper("每周 \(timesPerWeek) 次", value: $timesPerWeek, in: 1...7)
                }

            case .task:
                goalPicker
                Toggle("设置日期", isOn: $hasTaskDate)
                if hasTaskDate {
                    DatePicker("日期", selection: $taskDate, displayedComponents: .date)
                }
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(saveTitle) {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(canSave == false)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    @ViewBuilder
    private var goalPicker: some View {
        if goals.isEmpty {
            Text("还没有恒星。先捕获一个目标，再给它添加轨道或事项。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(10)
                .background(.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Picker("所属恒星", selection: $selectedGoalId) {
                ForEach(goals) { goal in
                    Text(goal.title).tag(goal.id)
                }
            }
        }
    }

    private var placeholder: String {
        switch mode {
        case .goal:
            return "想创造哪颗恒星？"
        case .routine:
            return "想固定成哪条轨道？"
        case .task:
            return "临时要完成什么？"
        }
    }

    private var saveTitle: String {
        switch mode {
        case .goal:
            return "创造"
        case .routine:
            return "加入轨道"
        case .task:
            return "加入事项"
        }
    }

    private func save() {
        switch mode {
        case .goal:
            onCreateGoal(
                title,
                DateCoding.dateString(from: startDate),
                hasDueDate ? DateCoding.dateString(from: dueDate) : nil
            )
        case .routine:
            onCreateRoutine(
                selectedGoalId,
                title,
                isWeekly ? .weeklyCount(timesPerWeek: timesPerWeek) : .daily
            )
        case .task:
            onCreateTask(
                selectedGoalId,
                title,
                hasTaskDate ? DateCoding.dateString(from: taskDate) : nil
            )
        }
    }
}

struct GoalEditorView: View {
    var goal: Goal?
    var onSave: (String, ISODate, ISODate?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var startDate: Date
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(goal: Goal?, onSave: @escaping (String, ISODate, ISODate?) -> Void) {
        self.goal = goal
        self.onSave = onSave
        _title = State(initialValue: goal?.title ?? "")
        _startDate = State(initialValue: goal.flatMap { DateCoding.parseDate($0.startDate) } ?? Date())
        _hasDueDate = State(initialValue: goal?.dueDate != nil)
        _dueDate = State(initialValue: goal?.dueDate.flatMap { DateCoding.parseDate($0) } ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(goal == nil ? "创造恒星" : "编辑恒星")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            TextField("目标名称", text: $title)
                .textFieldStyle(.roundedBorder)

            DatePicker("开始日期", selection: $startDate, displayedComponents: .date)

            Toggle("设置完成期限", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("完成期限", selection: $dueDate, displayedComponents: .date)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    onSave(
                        title,
                        DateCoding.dateString(from: startDate),
                        hasDueDate ? DateCoding.dateString(from: dueDate) : nil
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

struct RoutineEditorView: View {
    var routine: Routine?
    var onSave: (String, RoutineFrequency) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var isWeekly: Bool
    @State private var timesPerWeek: Int

    init(routine: Routine?, onSave: @escaping (String, RoutineFrequency) -> Void) {
        self.routine = routine
        self.onSave = onSave

        _title = State(initialValue: routine?.title ?? "")
        if case let .weeklyCount(timesPerWeek) = routine?.frequency {
            _isWeekly = State(initialValue: true)
            _timesPerWeek = State(initialValue: timesPerWeek)
        } else {
            _isWeekly = State(initialValue: false)
            _timesPerWeek = State(initialValue: 2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(routine == nil ? "新增轨道" : "编辑轨道")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            TextField("Routine 名称", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("频率", selection: $isWeekly) {
                Text("每日").tag(false)
                Text("每周 N 次").tag(true)
            }
            .pickerStyle(.segmented)

            if isWeekly {
                Stepper("每周 \(timesPerWeek) 次", value: $timesPerWeek, in: 1...7)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    onSave(title, isWeekly ? .weeklyCount(timesPerWeek: timesPerWeek) : .daily)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

struct TaskEditorView: View {
    var task: OneOffTask?
    var onSave: (String, ISODate?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var hasDate: Bool
    @State private var date: Date

    init(task: OneOffTask?, onSave: @escaping (String, ISODate?) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _hasDate = State(initialValue: task?.date != nil)
        _date = State(initialValue: task?.date.flatMap { DateCoding.parseDate($0) } ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(task == nil ? "新增临时事项" : "编辑临时事项")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            TextField("事项名称", text: $title)
                .textFieldStyle(.roundedBorder)

            Toggle("设置日期", isOn: $hasDate)
            if hasDate {
                DatePicker("日期", selection: $date, displayedComponents: .date)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    onSave(title, hasDate ? DateCoding.dateString(from: date) : nil)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
