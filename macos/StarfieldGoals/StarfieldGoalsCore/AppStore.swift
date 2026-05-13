import Combine
import Foundation

@MainActor
public final class AppStore: ObservableObject {
    @Published public private(set) var state: AppState
    @Published public private(set) var lastSavedAt: Date?
    @Published public private(set) var storageMessage: String?
    @Published public private(set) var storageStatus: StoredStateStatus

    private let storage: StorageService?
    private let autosaves: Bool

    public init(
        initialState: AppState = .empty,
        storage: StorageService? = StorageService(),
        autosaves: Bool = true
    ) {
        self.storage = storage
        self.autosaves = autosaves

        if initialState != .empty || !autosaves {
            state = initialState
            storageStatus = .empty
        } else if let storage {
            let result = storage.load()
            state = result.state
            storageStatus = result.status
            storageMessage = result.message
        } else {
            state = initialState
            storageStatus = .empty
        }
    }

    @discardableResult
    public func addGoal(title: String, startDate: ISODate, dueDate: ISODate?) -> Goal {
        let now = DateCoding.nowTimestamp()
        let goal = Goal(
            id: makeID("goal"),
            title: clean(title, fallback: "未命名恒星"),
            startDate: startDate,
            dueDate: dueDate,
            status: .active,
            completedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        state.goals.append(goal)
        persistIfNeeded()
        return goal
    }

    public func updateGoal(_ goal: Goal) {
        guard let index = state.goals.firstIndex(where: { $0.id == goal.id }) else {
            return
        }
        var next = goal
        next.updatedAt = DateCoding.nowTimestamp()
        state.goals[index] = next
        persistIfNeeded()
    }

    public func deleteGoal(_ goalId: String) {
        let routineIds = Set(state.routines.filter { $0.goalId == goalId }.map(\.id))
        state.goals.removeAll { $0.id == goalId }
        state.routines.removeAll { $0.goalId == goalId }
        state.tasks.removeAll { $0.goalId == goalId }
        state.checkIns.removeAll { routineIds.contains($0.routineId) }
        persistIfNeeded()
    }

    public func completeGoal(_ goalId: String, completed: Bool = true) {
        guard let index = state.goals.firstIndex(where: { $0.id == goalId }) else {
            return
        }
        let now = DateCoding.nowTimestamp()
        state.goals[index].status = completed ? .completed : .active
        state.goals[index].completedAt = completed ? now : nil
        state.goals[index].updatedAt = now
        persistIfNeeded()
    }

    @discardableResult
    public func addRoutine(goalId: String, title: String, frequency: RoutineFrequency) -> Routine {
        let now = DateCoding.nowTimestamp()
        let routine = Routine(
            id: makeID("routine"),
            goalId: goalId,
            title: clean(title, fallback: "未命名轨道"),
            frequency: frequency,
            createdAt: now,
            updatedAt: now
        )
        state.routines.append(routine)
        persistIfNeeded()
        return routine
    }

    public func updateRoutine(_ routine: Routine) {
        guard let index = state.routines.firstIndex(where: { $0.id == routine.id }) else {
            return
        }
        var next = routine
        next.updatedAt = DateCoding.nowTimestamp()
        state.routines[index] = next
        persistIfNeeded()
    }

    public func deleteRoutine(_ routineId: String) {
        state.routines.removeAll { $0.id == routineId }
        state.checkIns.removeAll { $0.routineId == routineId }
        persistIfNeeded()
    }

    @discardableResult
    public func addTask(goalId: String, title: String, date: ISODate?) -> OneOffTask {
        let task = OneOffTask(
            id: makeID("task"),
            goalId: goalId,
            title: clean(title, fallback: "未命名事项"),
            completed: false,
            date: date,
            createdAt: DateCoding.nowTimestamp(),
            completedAt: nil
        )
        state.tasks.append(task)
        persistIfNeeded()
        return task
    }

    public func toggleTask(_ taskId: String, completed: Bool) {
        guard let index = state.tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        state.tasks[index].completed = completed
        state.tasks[index].completedAt = completed ? DateCoding.nowTimestamp() : nil
        persistIfNeeded()
    }

    public func updateTask(_ task: OneOffTask) {
        guard let index = state.tasks.firstIndex(where: { $0.id == task.id }) else {
            return
        }
        var next = task
        next.title = clean(task.title, fallback: "未命名事项")
        state.tasks[index] = next
        persistIfNeeded()
    }

    public func deleteTask(_ taskId: String) {
        state.tasks.removeAll { $0.id == taskId }
        persistIfNeeded()
    }

    public func toggleCheckIn(routineId: String, date: ISODate, completed: Bool) {
        let now = DateCoding.nowTimestamp()
        if let index = state.checkIns.firstIndex(where: { $0.routineId == routineId && $0.date == date }) {
            state.checkIns[index].completed = completed
            state.checkIns[index].recordedAt = now
        } else if completed {
            state.checkIns.append(
                CheckIn(
                    id: makeID("check"),
                    routineId: routineId,
                    date: date,
                    completed: true,
                    recordedAt: now
                )
            )
        }
        persistIfNeeded()
    }

    public func markReminderSent(on date: ISODate) {
        state.lastReminderDate = date
        persistIfNeeded()
    }

    public func hydrate(_ nextState: AppState) {
        state = nextState
        persistIfNeeded()
    }

    public func stats(for goalId: String, today: ISODate = DomainLogic.todayISO()) -> GoalStats? {
        guard let goal = state.goals.first(where: { $0.id == goalId }) else {
            return nil
        }
        return DomainLogic.goalStats(
            goal: goal,
            routines: state.routines,
            tasks: state.tasks,
            checkIns: state.checkIns,
            today: today
        )
    }

    public func reviewItems(for date: ISODate = DomainLogic.todayISO()) -> [CheckInItem] {
        DomainLogic.buildCheckInItems(
            goals: state.goals,
            routines: state.routines,
            checkIns: state.checkIns,
            date: date
        )
    }

    public func requestSaveNow() {
        persist()
    }

    private func persistIfNeeded() {
        guard autosaves else {
            return
        }
        persist()
    }

    private func persist() {
        guard let storage else {
            return
        }

        switch storage.save(state) {
        case let .success(date):
            lastSavedAt = date
            storageStatus = .ok
            storageMessage = nil
        case let .failure(error):
            storageMessage = error.localizedDescription
        }
    }

    private func clean(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func makeID(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.lowercased())"
    }
}
