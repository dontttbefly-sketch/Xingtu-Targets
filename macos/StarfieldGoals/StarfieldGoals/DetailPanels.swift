import StarfieldGoalsCore
import SwiftUI
import UniformTypeIdentifiers

struct GoalDetailView: View {
    var goal: Goal
    var routines: [Routine]
    var tasks: [OneOffTask]
    var stats: GoalStats?
    var checkIns: [CheckIn]
    var today: ISODate

    var onEditGoal: () -> Void
    var onNewRoutine: () -> Void
    var onEditRoutine: (Routine) -> Void
    var onDeleteRoutine: (Routine) -> Void
    var onToggleRoutineToday: (Routine, Bool) -> Void
    var onNewTask: () -> Void
    var onEditTask: (OneOffTask) -> Void
    var onToggleTask: (OneOffTask, Bool) -> Void
    var onDeleteTask: (OneOffTask) -> Void
    var onCompleteGoal: (Bool) -> Void
    var onDeleteGoal: () -> Void
    var onClose: () -> Void

    @State private var showingDeleteGoalConfirmation = false
    @State private var routinePendingDeletion: Routine?
    @State private var taskPendingDeletion: OneOffTask?

    private var goalTodayProgress: TodayProgress {
        DomainLogic.todayProgress(goals: [goal], routines: routines, checkIns: checkIns, date: today)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("恒星档案")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.52))
                        Text(goal.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("星图") { onClose() }
                        .buttonStyle(HUDButtonStyle())
                }

                GoalTodayStatus(progress: goalTodayProgress)

                statsGrid

                HStack {
                    Button("编辑恒星", action: onEditGoal)
                        .buttonStyle(HUDButtonStyle())
                    Button(goal.status == .completed ? "恢复进行中" : "标记点亮") {
                        onCompleteGoal(goal.status != .completed)
                    }
                    .buttonStyle(PrimaryHUDButtonStyle())
                }

                SectionHeader(title: "轨道 Routine", actionTitle: "新增轨道", action: onNewRoutine)
                VStack(spacing: 8) {
                    if routines.isEmpty {
                        EmptyLine("还没有轨道。给这颗恒星添加一个每日或每周 routine。")
                    } else {
                        ForEach(routines) { routine in
                            RoutineRow(
                                routine: routine,
                                checkIns: checkIns,
                                today: today,
                                onToggleToday: { completed in onToggleRoutineToday(routine, completed) },
                                onEdit: { onEditRoutine(routine) },
                                onDelete: { routinePendingDeletion = routine }
                            )
                        }
                    }
                }

                SectionHeader(title: "临时事项", actionTitle: "新增事项", action: onNewTask)
                VStack(spacing: 8) {
                    if tasks.isEmpty {
                        EmptyLine("没有临时事项。")
                    } else {
                        ForEach(tasks) { task in
                            HStack(spacing: 10) {
                                Toggle("", isOn: Binding(
                                    get: { task.completed },
                                    set: { onToggleTask(task, $0) }
                                ))
                                .toggleStyle(.checkbox)
                                Text(task.title)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .strikethrough(task.completed)
                                Spacer()
                                if let date = task.date {
                                    Text(date)
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.42))
                                }
                                Button("编辑") { onEditTask(task) }
                                    .buttonStyle(HUDButtonStyle())
                                Button("删除") { taskPendingDeletion = task }
                                    .buttonStyle(HUDButtonStyle())
                            }
                            .padding(10)
                            .background(.white.opacity(0.055))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                Button("删除这颗恒星") {
                    showingDeleteGoalConfirmation = true
                }
                .buttonStyle(DangerButtonStyle())
            }
            .padding(18)
        }
        .frame(width: 468)
        .background(.black.opacity(0.26))
        .background(.ultraThinMaterial.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        )
        .confirmationDialog("删除这颗恒星？", isPresented: $showingDeleteGoalConfirmation) {
            Button("删除恒星、轨道、事项和打卡记录", role: .destructive) {
                onDeleteGoal()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这个操作会同时删除关联的 routines、临时事项和 check-in。")
        }
        .confirmationDialog(
            "删除这个 routine？",
            isPresented: Binding(
                get: { routinePendingDeletion != nil },
                set: { if !$0 { routinePendingDeletion = nil } }
            )
        ) {
            Button("删除 routine 和关联打卡", role: .destructive) {
                if let routinePendingDeletion {
                    onDeleteRoutine(routinePendingDeletion)
                }
                routinePendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                routinePendingDeletion = nil
            }
        }
        .confirmationDialog(
            "删除这个临时事项？",
            isPresented: Binding(
                get: { taskPendingDeletion != nil },
                set: { if !$0 { taskPendingDeletion = nil } }
            )
        ) {
            Button("删除事项", role: .destructive) {
                if let taskPendingDeletion {
                    onDeleteTask(taskPendingDeletion)
                }
                taskPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                taskPendingDeletion = nil
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            StatTile(title: "开始天数", value: "\(stats?.daysStarted ?? 0)")
            StatTile(title: "剩余天数", value: stats?.daysRemaining.map(String.init) ?? "∞")
            StatTile(title: "完成次数", value: "\(stats?.completedCheckIns ?? 0)")
            StatTile(title: "完成率", value: "\(stats?.completionRate ?? 0)%")
        }
    }
}

private struct GoalTodayStatus: View {
    var progress: TodayProgress

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(progress.completionRate) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.91, green: 0.82, blue: 0.55),
                                Color(red: 0.58, green: 0.76, blue: 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(progress.completed)/\(progress.total)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(progress.remaining == 0 ? "今日轨道已稳定点亮" : "今日还有 \(progress.remaining) 条轨道")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("复盘或在下方 routine 行内点亮，都将同步到星图。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct RoutineRow: View {
    var routine: Routine
    var checkIns: [CheckIn]
    var today: ISODate
    var onToggleToday: (Bool) -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var completedToday: Bool {
        DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: today)
    }

    private var canCompleteToday: Bool {
        DomainLogic.canCompleteRoutine(on: today, routine: routine, checkIns: checkIns)
    }

    private var momentum: RoutineMomentum {
        DomainLogic.routineMomentum(routine, checkIns: checkIns, today: today)
    }

    private var momentumText: String {
        if let target = momentum.weekTarget {
            return "本周 \(momentum.weekCompleted)/\(target) · 累计 \(momentum.completedTotal) 次"
        }
        if momentum.currentDailyStreak > 0 {
            return "连续 \(momentum.currentDailyStreak) 天 · 累计 \(momentum.completedTotal) 次"
        }
        return momentum.completedTotal == 0 ? "尚未点亮" : "累计 \(momentum.completedTotal) 次"
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(DomainLogic.frequencyLabel(routine.frequency))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                Text(momentumText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Spacer()

            Button(completedToday ? "已点亮" : (canCompleteToday ? "今日点亮" : "本周已达标")) {
                onToggleToday(!completedToday)
            }
            .buttonStyle(completedToday ? AnyButtonStyle(HUDButtonStyle()) : AnyButtonStyle(PrimaryHUDButtonStyle()))
            .disabled(!completedToday && !canCompleteToday)

            Button("编辑", action: onEdit)
                .buttonStyle(HUDButtonStyle())
            Button("删除", action: onDelete)
                .buttonStyle(HUDButtonStyle())
        }
        .padding(10)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct RoutineQuickPanel: View {
    var routine: Routine
    var checkIns: [CheckIn]
    var today: ISODate
    var onToggleToday: (Bool) -> Void
    var onEdit: () -> Void
    var onClose: () -> Void

    private var completedToday: Bool {
        DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: today)
    }

    private var momentum: RoutineMomentum {
        DomainLogic.routineMomentum(routine, checkIns: checkIns, today: today)
    }

    private var momentumText: String {
        if let target = momentum.weekTarget {
            return "本周 \(momentum.weekCompleted)/\(target) · 累计 \(momentum.completedTotal) 次"
        }
        if momentum.currentDailyStreak > 0 {
            return "连续 \(momentum.currentDailyStreak) 天 · 累计 \(momentum.completedTotal) 次"
        }
        return momentum.completedTotal == 0 ? "尚未点亮" : "累计 \(momentum.completedTotal) 次"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("行星信标")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                Spacer()
                Button("关闭", action: onClose)
                    .buttonStyle(HUDButtonStyle())
            }
            Text(routine.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(2)
            Text(DomainLogic.frequencyLabel(routine.frequency))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(momentumText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.52))
            HStack {
                Button(completedToday ? "取消今日点亮" : "今日点亮") {
                    onToggleToday(!completedToday)
                }
                .buttonStyle(PrimaryHUDButtonStyle())
                Button("编辑", action: onEdit)
                    .buttonStyle(HUDButtonStyle())
            }
        }
        .padding(14)
        .frame(width: 278)
        .background(.black.opacity(0.20))
        .background(.ultraThinMaterial.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 22, x: 0, y: 14)
        .padding(.leading, 32)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

struct TodayPanel: View {
    var agenda: TodayAgenda
    var checkIns: [CheckIn]
    var today: ISODate
    var onToggleRoutine: (Routine, Bool) -> Void
    var onToggleTask: (OneOffTask, Bool) -> Void
    var onSelectGoal: (String) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日轨道")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(today)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Button("关闭", action: onClose)
                    .buttonStyle(HUDButtonStyle())
            }

            ReviewProgressHeader(progress: agenda.progress, date: today)

            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    TodaySectionTitle(title: "今天要点亮的轨道", count: agenda.routineItems.count)
                    if agenda.routineItems.isEmpty {
                        EmptyLine("今天没有强提醒轨道。可以去恒星档案添加 routine。")
                    } else {
                        ForEach(agenda.routineItems) { item in
                            TodayRoutineRow(
                                item: item,
                                checkIns: checkIns,
                                today: today,
                                onToggle: { completed in
                                    onToggleRoutine(item.routine, completed)
                                },
                                onSelectGoal: {
                                    onSelectGoal(item.goal.id)
                                }
                            )
                        }
                    }

                    TodaySectionTitle(title: "临时事项", count: agenda.taskItems.count)
                    if agenda.taskItems.isEmpty {
                        EmptyLine("没有需要今天处理的临时事项。")
                    } else {
                        ForEach(agenda.taskItems) { item in
                            TodayTaskRow(
                                item: item,
                                onToggle: { completed in
                                    onToggleTask(item.task, completed)
                                },
                                onSelectGoal: {
                                    onSelectGoal(item.goal.id)
                                }
                            )
                        }
                    }
                }
            }
        }
        .panelChrome(width: 468)
    }
}

private struct TodaySectionTitle: View {
    var title: String
    var count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white.opacity(0.07))
                .clipShape(Capsule())
            Spacer()
        }
    }
}

private struct TodayRoutineRow: View {
    var item: CheckInItem
    var checkIns: [CheckIn]
    var today: ISODate
    var onToggle: (Bool) -> Void
    var onSelectGoal: () -> Void

    private var completedToday: Bool {
        DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: item.routine.id, date: today)
    }

    private var momentum: RoutineMomentum {
        DomainLogic.routineMomentum(item.routine, checkIns: checkIns, today: today)
    }

    private var progressText: String {
        if let target = momentum.weekTarget {
            return "本周 \(momentum.weekCompleted)/\(target)"
        }
        if momentum.currentDailyStreak > 0 {
            return "连续 \(momentum.currentDailyStreak) 天"
        }
        return "累计 \(momentum.completedTotal) 次"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelectGoal) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.routine.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Text("\(item.goal.title) · \(DomainLogic.frequencyLabel(item.routine.frequency)) · \(progressText)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(completedToday ? "已点亮" : "点亮") {
                onToggle(!completedToday)
            }
            .buttonStyle(completedToday ? AnyButtonStyle(HUDButtonStyle()) : AnyButtonStyle(PrimaryHUDButtonStyle()))
        }
        .padding(10)
        .background(.white.opacity(completedToday ? 0.04 : 0.065))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TodayTaskRow: View {
    var item: TodayTaskItem
    var onToggle: (Bool) -> Void
    var onSelectGoal: () -> Void

    private var dateText: String {
        item.task.date.map { " · \($0)" } ?? ""
    }

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { item.task.completed },
                set: { onToggle($0) }
            ))
            .toggleStyle(.checkbox)

            Button(action: onSelectGoal) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.task.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Text("\(item.goal.title)\(dateText)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ReviewPanel: View {
    var itemsProvider: (ISODate) -> [CheckInItem]
    var checkIns: [CheckIn]
    var onToggle: (String, ISODate, Bool) -> Void
    var onClose: () -> Void

    @State private var selectedDate = DomainLogic.todayISO()

    private var dates: [ISODate] {
        DomainLogic.backfillDates(through: DomainLogic.todayISO())
    }

    private var selectedItems: [CheckInItem] {
        itemsProvider(selectedDate)
    }

    private var selectedProgress: TodayProgress {
        TodayProgress(
            completed: selectedItems.filter {
                DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: $0.routine.id, date: selectedDate)
            }.count,
            total: selectedItems.count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今晚复盘")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("可补记近 7 天")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Button("关闭", action: onClose)
                    .buttonStyle(HUDButtonStyle())
            }

            Picker("日期", selection: $selectedDate) {
                ForEach(dates, id: \.self) { date in
                    Text(dateChipLabel(date)).tag(date)
                }
            }
            .pickerStyle(.segmented)

            ReviewProgressHeader(progress: selectedProgress, date: selectedDate)

            ScrollView {
                VStack(spacing: 8) {
                    let items = selectedItems
                    if items.isEmpty {
                        EmptyLine("这一天没有需要复盘的轨道。")
                    } else {
                        ForEach(items) { item in
                            let completed = DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: item.routine.id, date: selectedDate)
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.routine.title)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    Text("\(item.goal.title) · \(DomainLogic.frequencyLabel(item.routine.frequency))")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.52))
                                }
                                Spacer()
                                Button(completed ? "已点亮" : "点亮") {
                                    onToggle(item.routine.id, selectedDate, !completed)
                                }
                                .buttonStyle(completed ? AnyButtonStyle(HUDButtonStyle()) : AnyButtonStyle(PrimaryHUDButtonStyle()))
                            }
                            .padding(10)
                            .background(.white.opacity(0.055))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .panelChrome(width: 468)
    }

    private func dateChipLabel(_ date: ISODate) -> String {
        guard let index = dates.firstIndex(of: date) else {
            return String(date.suffix(5))
        }
        switch index {
        case 0:
            return "今天"
        case 1:
            return "昨天"
        default:
            return String(date.suffix(5))
        }
    }
}

private struct ReviewProgressHeader: View {
    var progress: TodayProgress
    var date: ISODate

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(progress.completionRate) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.83, blue: 0.52),
                                Color(red: 0.56, green: 0.74, blue: 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(progress.completed)/\(progress.total)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(progress.remaining == 0 ? "这一天的轨道已全部点亮" : "还有 \(progress.remaining) 条轨道等待点亮")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("\(date) · 只呈现这一天该点亮的轨道，也可补记近 7 天。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

struct DataVaultView: View {
    var state: AppState
    var lastSavedAt: Date?
    var storageStatus: StoredStateStatus
    var storageMessage: String?
    var onSaveNow: () -> Void
    var onImport: (AppState) -> Void
    var onMessage: (String?) -> Void
    var onClose: () -> Void

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument = BackupDocument(data: Data())
    @State private var pendingImport: AppState?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据舱")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Button("关闭", action: onClose)
                    .buttonStyle(HUDButtonStyle())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                StatTile(title: "目标", value: "\(state.goals.count)")
                StatTile(title: "Routine", value: "\(state.routines.count)")
                StatTile(title: "打卡", value: "\(state.checkIns.count)")
                StatTile(title: "最后保存", value: lastSavedAt.map(shortTime) ?? "--")
            }

            if let storageMessage {
                Text(storageMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.yellow.opacity(0.9))
                    .padding(10)
                    .background(.yellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack {
                Button("立即保存", action: onSaveNow)
                    .buttonStyle(HUDButtonStyle())
                Button("导出备份") {
                    do {
                        exportDocument = BackupDocument(data: try BackupService().exportBackup(state: state))
                        showingExporter = true
                        onMessage(nil)
                    } catch {
                        onMessage(error.localizedDescription)
                    }
                }
                .buttonStyle(PrimaryHUDButtonStyle())
                Button("导入备份") {
                    showingImporter = true
                }
                .buttonStyle(HUDButtonStyle())
            }

            Text("数据保存在本机 Application Support。Web 版数据舱导出的 JSON 可以在这里导入，导入会覆盖当前 macOS 本地星图。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .lineSpacing(3)
        }
        .panelChrome(width: 468)
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "starfield-goals-backup-\(DomainLogic.todayISO()).json"
        ) { result in
            if case let .failure(error) = result {
                onMessage(error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let data = try Data(contentsOf: url)
                let imported = try BackupService().importBackup(data: data)
                pendingImport = imported
                onMessage("备份已读取，确认后会覆盖当前本机星图。")
            } catch {
                onMessage(error.localizedDescription)
            }
        }
        .confirmationDialog(
            "导入备份会覆盖当前星图？",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            )
        ) {
            Button("覆盖并导入备份", role: .destructive) {
                if let pendingImport {
                    onImport(pendingImport)
                }
                pendingImport = nil
            }
            Button("取消", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            Text("当前本机目标、routine、临时事项和打卡记录会被备份文件中的星图替换。")
        }
    }

    private var statusText: String {
        switch storageStatus {
        case .ok:
            return "本地保存正常"
        case .empty:
            return "等待第一次保存"
        case .recovered:
            return "已从 last-good 恢复"
        case .invalid:
            return "本地数据异常"
        }
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct VoyageLogView: View {
    var state: AppState
    var today: ISODate
    var onSelectGoal: (String) -> Void
    var onClose: () -> Void

    private var summary: VoyageSummary {
        DomainLogic.voyageSummary(
            goals: state.goals,
            routines: state.routines,
            tasks: state.tasks,
            checkIns: state.checkIns,
            today: today
        )
    }

    private var goalsBySignal: [Goal] {
        state.goals.sorted { lhs, rhs in
            let lhsStats = DomainLogic.goalStats(goal: lhs, routines: state.routines, tasks: state.tasks, checkIns: state.checkIns, today: today)
            let rhsStats = DomainLogic.goalStats(goal: rhs, routines: state.routines, tasks: state.tasks, checkIns: state.checkIns, today: today)
            if lhs.status != rhs.status {
                return lhs.status == .active
            }
            return lhsStats.completionRate > rhsStats.completionRate
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("航行日志")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("把坚持变成可回看的星系记录")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Button("关闭", action: onClose)
                    .buttonStyle(HUDButtonStyle())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                StatTile(title: "今日点亮", value: "\(summary.todayProgress.completed)/\(summary.todayProgress.total)")
                StatTile(title: "本周点亮", value: "\(summary.weeklyCheckIns)")
                StatTile(title: "累计点亮", value: "\(summary.completedCheckIns)")
                StatTile(title: "完成恒星", value: "\(summary.completedGoals)")
                StatTile(title: "活跃恒星", value: "\(summary.activeGoals)")
                StatTile(title: "临时事项", value: "\(summary.completedTasks)/\(summary.totalTasks)")
            }

            Text("恒星推进")
                .font(.system(size: 14, weight: .bold, design: .rounded))

            ScrollView {
                VStack(spacing: 8) {
                    if goalsBySignal.isEmpty {
                        EmptyLine("还没有恒星。创造第一颗恒星后，航行日志会记录它的推进。")
                    } else {
                        ForEach(goalsBySignal) { goal in
                            let stats = DomainLogic.goalStats(
                                goal: goal,
                                routines: state.routines,
                                tasks: state.tasks,
                                checkIns: state.checkIns,
                                today: today
                            )
                            Button {
                                onSelectGoal(goal.id)
                            } label: {
                                GoalProgressRow(goal: goal, stats: stats)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .panelChrome(width: 468)
    }
}

private struct GoalProgressRow: View {
    var goal: Goal
    var stats: GoalStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Text(goal.status == .completed ? "已点亮恒星" : remainingText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text("\(stats.completionRate)%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(goal.status == .completed ? Color(red: 0.95, green: 0.82, blue: 0.52) : .white.opacity(0.86))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.73, blue: 0.89),
                                    Color(red: 0.94, green: 0.80, blue: 0.50)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * CGFloat(stats.completionRate) / 100)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(.white.opacity(0.052))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(goal.status == .completed ? 0.16 : 0.08), lineWidth: 1)
        )
    }

    private var remainingText: String {
        if let days = stats.daysRemaining {
            return "已航行 \(stats.daysStarted) 天，剩余 \(days) 天"
        }
        return "已航行 \(stats.daysStarted) 天"
    }
}

struct TodayActionDock: View {
    var agenda: TodayAgenda
    var checkIns: [CheckIn]
    var today: ISODate
    var onToggleRoutine: (Routine, Bool) -> Void
    var onToggleTask: (OneOffTask, Bool) -> Void
    var onOpenToday: () -> Void
    var onOpenReview: () -> Void

    private var nextRoutineItem: CheckInItem? {
        agenda.routineItems.first { item in
            DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: item.routine.id, date: today) == false
        }
    }

    private var nextTaskItem: TodayTaskItem? {
        agenda.taskItems.first
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.92, green: 0.82, blue: 0.54).opacity(0.20))
                        .frame(width: 28, height: 28)
                    Circle()
                        .fill(Color(red: 0.92, green: 0.82, blue: 0.54))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(red: 0.92, green: 0.82, blue: 0.54).opacity(0.75), radius: 10)
                }

                actionCopy

                HStack(spacing: 8) {
                    if let routineItem = nextRoutineItem {
                        Button("点亮") {
                            onToggleRoutine(routineItem.routine, true)
                        }
                        .buttonStyle(PrimaryHUDButtonStyle())
                    } else if let taskItem = nextTaskItem {
                        Button("完成") {
                            onToggleTask(taskItem.task, true)
                        }
                        .buttonStyle(PrimaryHUDButtonStyle())
                    }

                    Button("今日", action: onOpenToday)
                        .buttonStyle(HUDButtonStyle())

                    Button("复盘", action: onOpenReview)
                        .buttonStyle(HUDButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.black.opacity(0.28))
            .background(.ultraThinMaterial.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var actionCopy: some View {
        if let routineItem = nextRoutineItem {
            VStack(alignment: .leading, spacing: 2) {
                Text("下一条轨道 · \(routineItem.routine.title)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("\(routineItem.goal.title) · \(DomainLogic.frequencyLabel(routineItem.routine.frequency)) · 今日 \(agenda.progress.completed)/\(agenda.progress.total)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .frame(minWidth: 220, maxWidth: 360, alignment: .leading)
        } else if let taskItem = nextTaskItem {
            VStack(alignment: .leading, spacing: 2) {
                Text("临时事项 · \(taskItem.task.title)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("\(taskItem.goal.title)\(taskItem.task.date.map { " · \($0)" } ?? "")")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }
            .frame(minWidth: 220, maxWidth: 360, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日轨道已全部点亮")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("可以打开日志看看这一段航行。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(minWidth: 220, maxWidth: 360, alignment: .leading)
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct SectionHeader: View {
    var title: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(HUDButtonStyle())
        }
    }
}

private struct StatTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct EmptyLine: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.52))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.red.opacity(configuration.isPressed ? 0.72 : 0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.red.opacity(configuration.isPressed ? 0.12 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private extension View {
    func panelChrome(width: CGFloat) -> some View {
        self
            .padding(18)
            .frame(width: width)
            .background(.black.opacity(0.26))
            .background(.ultraThinMaterial.opacity(0.68))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            )
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
