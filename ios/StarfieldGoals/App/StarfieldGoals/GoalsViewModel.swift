import Foundation
import SwiftData

@MainActor
final class GoalsViewModel: ObservableObject {
    @Published private(set) var snapshot = RepositorySnapshot.empty
    @Published var activePanel: WorkspacePanel = .none
    @Published var selectedGoalId: String?
    @Published var selectedRoutineId: String?
    @Published var reviewDate: ISODate = todayISO()
    @Published var goalSearchText = ""
    @Published var errorMessage: String?
    @Published var dataMessage: String?
    @Published private var dismissedEveningReviewDate: ISODate?

    private var repository: GoalRepository?

    var today: ISODate {
        todayISO()
    }

    var selectedGoal: GoalSnapshot? {
        snapshot.goals.first { $0.id == selectedGoalId }
    }

    var detailGoal: GoalSnapshot? {
        switch activePanel {
        case .goalDetail(let goalId), .routineQuick(_, let goalId):
            return snapshot.goals.first { $0.id == goalId }
        case .none, .todayRoute, .review, .data, .quickAdd, .search:
            return selectedGoal
        }
    }

    var selectedRoutine: RoutineSnapshot? {
        guard let selectedRoutineId else {
            return nil
        }
        return snapshot.routines.first { $0.id == selectedRoutineId }
    }

    var activeGoals: [GoalSnapshot] {
        snapshot.goals.filter { $0.status == .active }
    }

    var completedGoals: [GoalSnapshot] {
        snapshot.goals.filter { $0.status == .completed }
    }

    var reviewItems: [CheckInItem] {
        buildCheckInItems(
            goals: snapshot.goals,
            routines: snapshot.routines,
            checkIns: snapshot.checkIns,
            date: reviewDate
        )
    }

    var todayRouteItems: [TodayRouteItem] {
        buildTodayRouteItems(
            goals: snapshot.goals,
            routines: snapshot.routines,
            tasks: snapshot.tasks,
            checkIns: snapshot.checkIns,
            date: today
        )
    }

    var todayPendingRouteItems: [TodayRouteItem] {
        todayRouteItems.filter { $0.status == .available }
    }

    var todayCompletedRouteItems: [TodayRouteItem] {
        todayRouteItems.filter { $0.status == .completedToday }
    }

    var todaySatisfiedWeeklyItems: [TodayRouteItem] {
        todayRouteItems.filter { $0.status == .weeklySatisfied }
    }

    var todayTasks: [OneOffTaskSnapshot] {
        snapshot.tasks.filter { task in
            guard !task.completed else {
                return false
            }
            return task.date == nil || task.date == today
        }
    }

    var streakSummary: StreakSummary {
        calculateStreakSummary(checkIns: snapshot.checkIns, through: today)
    }

    var averageCompletionRate: Int {
        guard !activeGoals.isEmpty else {
            return 0
        }
        let total = activeGoals.reduce(0) { partial, goal in
            partial + stats(for: goal).completionRate
        }
        return Int((Double(total) / Double(activeGoals.count)).rounded())
    }

    var nextSuggestedAction: TodayRouteItem? {
        todayPendingRouteItems.first
    }

    var goalHealth: [GoalHealth] {
        buildGoalHealth(
            goals: snapshot.goals,
            routines: snapshot.routines,
            tasks: snapshot.tasks,
            checkIns: snapshot.checkIns,
            today: today
        )
    }

    var attentionGoal: GoalHealth? {
        goalHealth.first
    }

    var stableRoutine: StableRoutineSummary? {
        mostStableRoutine(routines: snapshot.routines, checkIns: snapshot.checkIns)
    }

    var totalCompletedCheckIns: Int {
        snapshot.checkIns.filter(\.completed).count
    }

    var totalDays: Int {
        snapshot.goals.reduce(0) { total, goal in
            total + calculateGoalStats(
                goal: goal,
                routines: snapshot.routines,
                tasks: snapshot.tasks,
                checkIns: snapshot.checkIns,
                today: today
            ).daysStarted
        }
    }

    var filteredActiveGoals: [GoalSnapshot] {
        filteredGoals(activeGoals)
    }

    var filteredCompletedGoals: [GoalSnapshot] {
        filteredGoals(completedGoals)
    }

    var totalRecordCount: Int {
        snapshot.goals.count + snapshot.routines.count + snapshot.tasks.count + snapshot.checkIns.count
    }

    var importedWebStateAt: String? {
        snapshot.meta.importedWebStateAt
    }

    var shouldShowEveningReviewBanner: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 21 &&
            snapshot.meta.lastReminderDate != today &&
            dismissedEveningReviewDate != today
    }

    func configure(context: ModelContext) {
        if repository == nil {
            repository = GoalRepository(context: context)
        }
        refresh()
    }

    func refresh() {
        guard let repository else {
            return
        }
        do {
            snapshot = try repository.snapshot()
            if let selectedGoalId, !snapshot.goals.contains(where: { $0.id == selectedGoalId }) {
                self.selectedGoalId = nil
            }
            if let selectedRoutineId, !snapshot.routines.contains(where: { $0.id == selectedRoutineId }) {
                self.selectedRoutineId = nil
            }
            if let focusedGoalId = activePanel.focusedGoalId,
               !snapshot.goals.contains(where: { $0.id == focusedGoalId }) {
                activePanel = .none
            }
            errorMessage = nil
        } catch {
            errorMessage = readable(error)
        }
    }

    func resetWorkspace() {
        activePanel = .none
        selectedGoalId = nil
        selectedRoutineId = nil
    }

    func closePanel() {
        if activePanel.focusedGoalId != nil {
            selectedGoalId = nil
        }
        activePanel = .none
        selectedRoutineId = nil
    }

    func selectGoal(_ goalId: String) {
        selectedGoalId = goalId
        selectedRoutineId = nil
        activePanel = .none
    }

    func openGoal(_ goalId: String) {
        selectedGoalId = goalId
        selectedRoutineId = nil
        activePanel = .goalDetail(goalId: goalId)
    }

    func openRoutineQuick(_ routineId: String, goalId: String) {
        selectedGoalId = goalId
        selectedRoutineId = routineId
        activePanel = .routineQuick(routineId: routineId, goalId: goalId)
    }

    func openSelectedRoutineGoal() {
        guard let goalId = activePanel.focusedGoalId ?? selectedGoalId else {
            return
        }
        openGoal(goalId)
    }

    func openTodayRoute() {
        selectedRoutineId = nil
        activePanel = .todayRoute
    }

    func openReview() {
        reviewDate = today
        selectedRoutineId = nil
        activePanel = .review
    }

    func openDataVault() {
        selectedRoutineId = nil
        activePanel = .data
    }

    func openQuickAdd() {
        selectedRoutineId = nil
        activePanel = .quickAdd
    }

    func openSearch() {
        selectedRoutineId = nil
        activePanel = .search
    }

    func openToday() {
        openTodayRoute()
    }

    func openTodayFromNotification() {
        openReview()
    }

    func addGoal(
        title: String,
        startDate: ISODate,
        dueDate: ISODate?,
        colorHex: String? = nil,
        symbolName: String? = nil,
        domain: String? = nil
    ) {
        perform {
            try $0.addGoal(
                title: title,
                startDate: startDate,
                dueDate: dueDate,
                colorHex: colorHex,
                symbolName: symbolName,
                domain: domain
            )
        }
    }

    func updateGoal(
        _ goalId: String,
        title: String,
        startDate: ISODate,
        dueDate: ISODate?,
        colorHex: String? = nil,
        symbolName: String? = nil,
        domain: String? = nil
    ) {
        perform {
            try $0.updateGoal(
                goalId,
                title: title,
                startDate: startDate,
                dueDate: dueDate,
                colorHex: colorHex,
                symbolName: symbolName,
                domain: domain
            )
        }
    }

    func completeGoal(_ goalId: String) {
        perform { try $0.completeGoal(goalId) }
    }

    func deleteGoal(_ goalId: String) {
        perform {
            try $0.deleteGoal(goalId)
            selectedGoalId = nil
            selectedRoutineId = nil
            activePanel = .none
        }
    }

    func addRoutine(goalId: String, title: String, frequency: RoutineFrequency) {
        perform { try $0.addRoutine(goalId: goalId, title: title, frequency: frequency) }
    }

    func updateRoutine(_ routineId: String, title: String, frequency: RoutineFrequency) {
        perform { try $0.updateRoutine(routineId, title: title, frequency: frequency) }
    }

    func deleteRoutine(_ routineId: String) {
        perform {
            try $0.deleteRoutine(routineId)
            if selectedRoutineId == routineId {
                selectedRoutineId = nil
                activePanel = .none
            }
        }
    }

    func toggleCheckIn(routineId: String, date: ISODate, completed: Bool) {
        perform { try $0.toggleCheckIn(routineId: routineId, date: date, completed: completed) }
    }

    func addTask(
        goalId: String,
        title: String,
        date: ISODate?,
        priority: String? = nil,
        notes: String? = nil
    ) {
        perform {
            try $0.addTask(
                goalId: goalId,
                title: title,
                date: date,
                priority: priority,
                notes: notes
            )
        }
    }

    func toggleTask(_ taskId: String, completed: Bool) {
        perform { try $0.toggleTask(taskId, completed: completed) }
    }

    func deleteTask(_ taskId: String) {
        perform { try $0.deleteTask(taskId) }
    }

    func importWebState(from data: Data) {
        perform {
            let state = try WebAppStateV1.decodeCompatible(data)
            try $0.importWebState(state)
            dataMessage = "导入成功：已合并 Web 星图数据。"
        }
    }

    func exportWebState() -> Data? {
        do {
            return try repository?.exportWebState()
        } catch {
            errorMessage = readable(error)
            return nil
        }
    }

    func exportWebBackup() -> Data? {
        do {
            dataMessage = "导出成功：已生成 Web 兼容备份。"
            return try repository?.exportWebBackup()
        } catch {
            errorMessage = readable(error)
            return nil
        }
    }

    func markReminderSent(date: ISODate) {
        perform { try $0.markReminderSent(date: date) }
    }

    func acknowledgeEveningReviewBanner() {
        dismissedEveningReviewDate = today
        markReminderSent(date: today)
        openReview()
    }

    func stats(for goal: GoalSnapshot) -> GoalStats {
        calculateGoalStats(
            goal: goal,
            routines: snapshot.routines,
            tasks: snapshot.tasks,
            checkIns: snapshot.checkIns,
            today: today
        )
    }

    func routines(for goalId: String) -> [RoutineSnapshot] {
        snapshot.routines.filter { $0.goalId == goalId }
    }

    func tasks(for goalId: String) -> [OneOffTaskSnapshot] {
        snapshot.tasks.filter { $0.goalId == goalId }
    }

    func completedCheckInCount(for routineId: String) -> Int {
        snapshot.checkIns.filter { $0.routineId == routineId && $0.completed }.count
    }

    private func perform(_ operation: (GoalRepository) throws -> Void) {
        guard let repository else {
            errorMessage = "数据容器尚未准备好。"
            return
        }
        do {
            try operation(repository)
            refresh()
        } catch {
            errorMessage = readable(error)
        }
    }

    private func readable(_ error: Error) -> String {
        if let stateError = error as? WebAppStateError {
            switch stateError {
            case .invalidBackupEnvelope:
                return "导入失败：这不是星图目标管理的备份文件。"
            case .unsupportedVersion(let version):
                return "不支持的 Web 数据版本：\(version)。"
            }
        }
        return error.localizedDescription
    }

    private func filteredGoals(_ goals: [GoalSnapshot]) -> [GoalSnapshot] {
        let keyword = goalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return goals
        }
        return goals.filter { $0.title.localizedCaseInsensitiveContains(keyword) }
    }
}

private extension RepositorySnapshot {
    static let empty = RepositorySnapshot(
        goals: [],
        routines: [],
        tasks: [],
        checkIns: [],
        meta: AppMetaSnapshot()
    )
}
