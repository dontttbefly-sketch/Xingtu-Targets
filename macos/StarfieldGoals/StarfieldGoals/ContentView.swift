import StarfieldGoalsCore
import SwiftUI

private enum ActivePanel: Equatable {
    case none
    case today
    case review
    case dataVault
    case voyageLog
}

private enum SheetRoute: Identifiable {
    case quickCapture
    case newGoal
    case editGoal(String)
    case newRoutine(String)
    case editRoutine(String)
    case newTask(String)
    case editTask(String)

    var id: String {
        switch self {
        case .quickCapture:
            return "quick-capture"
        case .newGoal:
            return "new-goal"
        case let .editGoal(goalId):
            return "edit-goal-\(goalId)"
        case let .newRoutine(goalId):
            return "new-routine-\(goalId)"
        case let .editRoutine(routineId):
            return "edit-routine-\(routineId)"
        case let .newTask(goalId):
            return "new-task-\(goalId)"
        case let .editTask(taskId):
            return "edit-task-\(taskId)"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    @State private var selectedGoalId: String?
    @State private var selectedRoutineId: String?
    @State private var activePanel: ActivePanel = .none
    @State private var sheetRoute: SheetRoute?
    @State private var importMessage: String?

    private var selectedGoal: Goal? {
        selectedGoalId.flatMap { id in store.state.goals.first { $0.id == id } }
    }

    private var selectedRoutine: Routine? {
        selectedRoutineId.flatMap { id in store.state.routines.first { $0.id == id } }
    }

    private var todayProgress: TodayProgress {
        DomainLogic.todayProgress(
            goals: store.state.goals,
            routines: store.state.routines,
            checkIns: store.state.checkIns,
            date: DomainLogic.todayISO()
        )
    }

    private var todayAgenda: TodayAgenda {
        DomainLogic.todayAgenda(
            goals: store.state.goals,
            routines: store.state.routines,
            tasks: store.state.tasks,
            checkIns: store.state.checkIns,
            date: DomainLogic.todayISO()
        )
    }

    private var voyageSummary: VoyageSummary {
        DomainLogic.voyageSummary(
            goals: store.state.goals,
            routines: store.state.routines,
            tasks: store.state.tasks,
            checkIns: store.state.checkIns,
            today: DomainLogic.todayISO()
        )
    }

    var body: some View {
        ZStack {
            StarMapView(
                goals: store.state.goals,
                routines: store.state.routines,
                checkIns: store.state.checkIns,
                selectedGoalId: $selectedGoalId,
                onSelectGoal: { goalId in
                    selectedGoalId = goalId
                    selectedRoutineId = nil
                    activePanel = .none
                },
                onExitFocus: {
                    selectedGoalId = nil
                    selectedRoutineId = nil
                },
                onSelectRoutine: { routineId in
                    selectedRoutineId = routineId
                }
            )

            hudLayer

            panelLayer

            if shouldShowTodayDock {
                TodayActionDock(
                    agenda: todayAgenda,
                    checkIns: store.state.checkIns,
                    today: DomainLogic.todayISO(),
                    onToggleRoutine: { routine, completed in
                        store.toggleCheckIn(routineId: routine.id, date: DomainLogic.todayISO(), completed: completed)
                    },
                    onToggleTask: { task, completed in
                        store.toggleTask(task.id, completed: completed)
                    },
                    onOpenToday: {
                        selectedRoutineId = nil
                        selectedGoalId = nil
                        activePanel = .today
                    },
                    onOpenReview: {
                        selectedRoutineId = nil
                        selectedGoalId = nil
                        activePanel = .review
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
            }

            if let routine = selectedRoutine {
                RoutineQuickPanel(
                    routine: routine,
                    checkIns: store.state.checkIns,
                    today: DomainLogic.todayISO(),
                    onToggleToday: { completed in
                        store.toggleCheckIn(routineId: routine.id, date: DomainLogic.todayISO(), completed: completed)
                    },
                    onEdit: {
                        sheetRoute = .editRoutine(routine.id)
                    },
                    onClose: {
                        selectedRoutineId = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(6)
            }
        }
        .background(Color.black)
        .sheet(item: $sheetRoute) { route in
            sheet(for: route)
        }
        .onReceive(NotificationCenter.default.publisher(for: .starfieldCreateGoal)) { _ in
            sheetRoute = .newGoal
        }
        .onReceive(NotificationCenter.default.publisher(for: .starfieldQuickCapture)) { _ in
            sheetRoute = .quickCapture
        }
        .onReceive(NotificationCenter.default.publisher(for: .starfieldOpenToday)) { _ in
            selectedRoutineId = nil
            selectedGoalId = nil
            activePanel = .today
        }
        .onReceive(NotificationCenter.default.publisher(for: .starfieldOpenReview)) { _ in
            selectedRoutineId = nil
            selectedGoalId = nil
            activePanel = .review
        }
        .onReceive(NotificationCenter.default.publisher(for: .starfieldOpenDataVault)) { _ in
            selectedRoutineId = nil
            selectedGoalId = nil
            activePanel = .dataVault
        }
        .onReceive(NotificationCenter.default.publisher(for: .starfieldOpenVoyageLog)) { _ in
            selectedRoutineId = nil
            selectedGoalId = nil
            activePanel = .voyageLog
        }
        .onReceive(NotificationCenter.default.publisher(for: .starfieldReturnToMap)) { _ in
            selectedRoutineId = nil
            selectedGoalId = nil
            activePanel = .none
        }
    }

    private var hudLayer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Starfield Goals")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(hudSubtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                MetricPill(title: "今日点亮", value: "\(todayProgress.completed)/\(todayProgress.total)")
                MetricPill(title: "活跃恒星", value: "\(voyageSummary.activeGoals)")
                MetricPill(title: "已点亮", value: "\(voyageSummary.completedGoals)")
                MetricPill(title: "本周", value: "\(voyageSummary.weeklyCheckIns)")

                Button("创造恒星") {
                    sheetRoute = .newGoal
                }
                .keyboardShortcut("n", modifiers: .command)
                .buttonStyle(PrimaryHUDButtonStyle())

                Button("捕获") {
                    sheetRoute = .quickCapture
                }
                .keyboardShortcut("k", modifiers: .command)
                .buttonStyle(HUDButtonStyle())

                Button("今日") {
                    selectedRoutineId = nil
                    selectedGoalId = nil
                    activePanel = activePanel == .today ? .none : .today
                }
                .keyboardShortcut("t", modifiers: .command)
                .buttonStyle(HUDButtonStyle())

                Button("复盘") {
                    selectedRoutineId = nil
                    selectedGoalId = nil
                    activePanel = activePanel == .review ? .none : .review
                }
                .keyboardShortcut("r", modifiers: .command)
                .buttonStyle(HUDButtonStyle())

                Button("日志") {
                    selectedRoutineId = nil
                    selectedGoalId = nil
                    activePanel = activePanel == .voyageLog ? .none : .voyageLog
                }
                .keyboardShortcut("l", modifiers: .command)
                .buttonStyle(HUDButtonStyle())

                Button("数据") {
                    selectedRoutineId = nil
                    selectedGoalId = nil
                    activePanel = activePanel == .dataVault ? .none : .dataVault
                }
                .keyboardShortcut("d", modifiers: .command)
                .buttonStyle(HUDButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.22))
            .background(.ultraThinMaterial.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .opacity(selectedGoalId == nil ? 1 : 0.62)
            .scaleEffect(selectedGoalId == nil ? 1 : 0.985)
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()
        }
        .zIndex(3)
    }

    @ViewBuilder
    private var panelLayer: some View {
        HStack {
            Spacer()

            switch activePanel {
            case .today:
                TodayPanel(
                    agenda: todayAgenda,
                    checkIns: store.state.checkIns,
                    today: DomainLogic.todayISO(),
                    onToggleRoutine: { routine, completed in
                        store.toggleCheckIn(routineId: routine.id, date: DomainLogic.todayISO(), completed: completed)
                    },
                    onToggleTask: { task, completed in
                        store.toggleTask(task.id, completed: completed)
                    },
                    onSelectGoal: { goalId in
                        activePanel = .none
                        selectedRoutineId = nil
                        selectedGoalId = goalId
                    },
                    onClose: { activePanel = .none }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .review:
                ReviewPanel(
                    itemsProvider: { date in store.reviewItems(for: date) },
                    checkIns: store.state.checkIns,
                    onToggle: { routineId, date, completed in
                        store.toggleCheckIn(routineId: routineId, date: date, completed: completed)
                    },
                    onClose: { activePanel = .none }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .dataVault:
                DataVaultView(
                    state: store.state,
                    lastSavedAt: store.lastSavedAt,
                    storageStatus: store.storageStatus,
                    storageMessage: store.storageMessage ?? importMessage,
                    onSaveNow: { store.requestSaveNow() },
                    onImport: { state in
                        store.hydrate(state)
                        selectedGoalId = nil
                        selectedRoutineId = nil
                        importMessage = "备份已导入。"
                    },
                    onMessage: { importMessage = $0 },
                    onClose: { activePanel = .none }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .voyageLog:
                VoyageLogView(
                    state: store.state,
                    today: DomainLogic.todayISO(),
                    onSelectGoal: { goalId in
                        activePanel = .none
                        selectedRoutineId = nil
                        selectedGoalId = goalId
                    },
                    onClose: { activePanel = .none }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))

            case .none:
                if let goal = selectedGoal {
                    GoalDetailView(
                        goal: goal,
                        routines: store.state.routines.filter { $0.goalId == goal.id },
                        tasks: store.state.tasks.filter { $0.goalId == goal.id },
                        stats: store.stats(for: goal.id),
                        checkIns: store.state.checkIns,
                        today: DomainLogic.todayISO(),
                        onEditGoal: { sheetRoute = .editGoal(goal.id) },
                        onNewRoutine: { sheetRoute = .newRoutine(goal.id) },
                        onEditRoutine: { routine in sheetRoute = .editRoutine(routine.id) },
                        onDeleteRoutine: { routine in store.deleteRoutine(routine.id) },
                        onToggleRoutineToday: { routine, completed in
                            store.toggleCheckIn(routineId: routine.id, date: DomainLogic.todayISO(), completed: completed)
                        },
                        onNewTask: { sheetRoute = .newTask(goal.id) },
                        onEditTask: { task in sheetRoute = .editTask(task.id) },
                        onToggleTask: { task, completed in store.toggleTask(task.id, completed: completed) },
                        onDeleteTask: { task in store.deleteTask(task.id) },
                        onCompleteGoal: { completed in store.completeGoal(goal.id, completed: completed) },
                        onDeleteGoal: {
                            store.deleteGoal(goal.id)
                            selectedGoalId = nil
                            selectedRoutineId = nil
                        },
                        onClose: {
                            selectedGoalId = nil
                            selectedRoutineId = nil
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .padding(.top, 88)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .animation(.smooth(duration: 0.42), value: activePanel)
        .animation(.smooth(duration: 0.42), value: selectedGoalId)
        .zIndex(4)
    }

    @ViewBuilder
    private func sheet(for route: SheetRoute) -> some View {
        switch route {
        case .quickCapture:
            QuickCaptureView(
                goals: store.state.goals,
                onCreateGoal: { title, startDate, dueDate in
                    let goal = store.addGoal(title: title, startDate: startDate, dueDate: dueDate)
                    selectedGoalId = goal.id
                    activePanel = .none
                },
                onCreateRoutine: { goalId, title, frequency in
                    _ = store.addRoutine(goalId: goalId, title: title, frequency: frequency)
                    selectedGoalId = goalId
                    activePanel = .none
                },
                onCreateTask: { goalId, title, date in
                    _ = store.addTask(goalId: goalId, title: title, date: date)
                    selectedGoalId = goalId
                    activePanel = .none
                }
            )

        case .newGoal:
            GoalEditorView(goal: nil) { title, startDate, dueDate in
                let goal = store.addGoal(title: title, startDate: startDate, dueDate: dueDate)
                selectedGoalId = goal.id
            }

        case let .editGoal(goalId):
            if let goal = store.state.goals.first(where: { $0.id == goalId }) {
                GoalEditorView(goal: goal) { title, startDate, dueDate in
                    var next = goal
                    next.title = title
                    next.startDate = startDate
                    next.dueDate = dueDate
                    store.updateGoal(next)
                }
            }

        case let .newRoutine(goalId):
            RoutineEditorView(routine: nil) { title, frequency in
                _ = store.addRoutine(goalId: goalId, title: title, frequency: frequency)
            }

        case let .editRoutine(routineId):
            if let routine = store.state.routines.first(where: { $0.id == routineId }) {
                RoutineEditorView(routine: routine) { title, frequency in
                    var next = routine
                    next.title = title
                    next.frequency = frequency
                    store.updateRoutine(next)
                }
            }

        case let .newTask(goalId):
            TaskEditorView(task: nil) { title, date in
                _ = store.addTask(goalId: goalId, title: title, date: date)
            }

        case let .editTask(taskId):
            if let task = store.state.tasks.first(where: { $0.id == taskId }) {
                TaskEditorView(task: task) { title, date in
                    var next = task
                    next.title = title
                    next.date = date
                    store.updateTask(next)
                }
            }
        }
    }

    private var hudSubtitle: String {
        if store.state.goals.isEmpty {
            return "等待创建第一颗恒星"
        }
        if todayProgress.total == 0 {
            return "今日没有强提醒轨道"
        }
        if todayProgress.remaining == 0 {
            return "今日轨道已全部点亮"
        }
        return "还有 \(todayProgress.remaining) 条轨道等待点亮"
    }

    private var shouldShowTodayDock: Bool {
        store.state.goals.isEmpty == false &&
        (todayAgenda.progress.remaining > 0 || todayAgenda.taskItems.isEmpty == false) &&
        activePanel == .none &&
        selectedGoalId == nil &&
        selectedRoutineId == nil
    }
}

private struct MetricPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(minWidth: 54)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct HUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.72 : 0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(configuration.isPressed ? 0.13 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct PrimaryHUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.16))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.76, green: 0.88, blue: 0.95),
                        Color(red: 0.98, green: 0.86, blue: 0.64)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(configuration.isPressed ? 0.78 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
