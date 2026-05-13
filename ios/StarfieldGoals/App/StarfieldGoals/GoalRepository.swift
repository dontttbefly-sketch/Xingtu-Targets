import Foundation
import SwiftData

struct RepositorySnapshot {
    var goals: [GoalSnapshot]
    var routines: [RoutineSnapshot]
    var tasks: [OneOffTaskSnapshot]
    var checkIns: [CheckInSnapshot]
    var meta: AppMetaSnapshot

    var webState: WebAppStateV1 {
        WebAppStateV1(
            version: 1,
            goals: goals,
            routines: routines,
            tasks: tasks,
            checkIns: checkIns,
            lastReminderDate: meta.lastReminderDate
        )
    }
}

@MainActor
final class GoalRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func snapshot() throws -> RepositorySnapshot {
        let goals = try fetchGoals().map(\.snapshot)
        let routines = try fetchRoutines().map(\.snapshot)
        let tasks = try fetchTasks().map(\.snapshot)
        let checkIns = try fetchCheckIns().map(\.snapshot)
        let meta = try ensureMeta().snapshot
        return RepositorySnapshot(
            goals: goals,
            routines: routines,
            tasks: tasks,
            checkIns: checkIns,
            meta: meta
        )
    }

    func addGoal(
        title: String,
        startDate: ISODate,
        dueDate: ISODate?,
        colorHex: String? = nil,
        symbolName: String? = nil,
        domain: String? = nil
    ) throws {
        let now = nowString()
        context.insert(
            GoalRecord(
                id: makeId("goal"),
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                dueDate: dueDate?.isEmpty == true ? nil : dueDate,
                status: .active,
                completedAt: nil,
                createdAt: now,
                updatedAt: now,
                colorHex: colorHex,
                symbolName: symbolName,
                domain: domain,
                sortOrder: nil
            )
        )
        try save()
    }

    func updateGoal(
        _ goalId: String,
        title: String,
        startDate: ISODate,
        dueDate: ISODate?,
        colorHex: String? = nil,
        symbolName: String? = nil,
        domain: String? = nil
    ) throws {
        guard let record = try findGoal(goalId) else {
            return
        }
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.startDate = startDate
        record.dueDate = dueDate?.isEmpty == true ? nil : dueDate
        record.colorHex = colorHex
        record.symbolName = symbolName
        record.domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        record.updatedAt = nowString()
        try save()
    }

    func completeGoal(_ goalId: String) throws {
        guard let record = try findGoal(goalId) else {
            return
        }
        let now = nowString()
        record.statusRaw = GoalStatus.completed.rawValue
        record.completedAt = now
        record.updatedAt = now
        try save()
    }

    func deleteGoal(_ goalId: String) throws {
        let routines = try fetchRoutines().filter { $0.goalId == goalId }
        let routineIds = Set(routines.map(\.id))
        for checkIn in try fetchCheckIns().filter({ routineIds.contains($0.routineId) }) {
            context.delete(checkIn)
        }
        for routine in routines {
            context.delete(routine)
        }
        for task in try fetchTasks().filter({ $0.goalId == goalId }) {
            context.delete(task)
        }
        if let goal = try findGoal(goalId) {
            context.delete(goal)
        }
        try save()
    }

    func addRoutine(goalId: String, title: String, frequency: RoutineFrequency) throws {
        let now = nowString()
        context.insert(
            RoutineRecord(
                id: makeId("routine"),
                goalId: goalId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                frequency: frequency,
                createdAt: now,
                updatedAt: now
            )
        )
        try save()
    }

    func updateRoutine(_ routineId: String, title: String, frequency: RoutineFrequency) throws {
        guard let record = try findRoutine(routineId) else {
            return
        }
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.applyFrequencyFromRepository(frequency)
        record.updatedAt = nowString()
        try save()
    }

    func deleteRoutine(_ routineId: String) throws {
        for checkIn in try fetchCheckIns().filter({ $0.routineId == routineId }) {
            context.delete(checkIn)
        }
        if let routine = try findRoutine(routineId) {
            context.delete(routine)
        }
        try save()
    }

    func toggleCheckIn(routineId: String, date: ISODate, completed: Bool) throws {
        let now = nowString()
        if let record = try fetchCheckIns().first(where: { $0.routineId == routineId && $0.date == date }) {
            record.completed = completed
            record.recordedAt = now
        } else {
            context.insert(
                CheckInRecord(
                    id: makeId("check"),
                    routineId: routineId,
                    date: date,
                    completed: completed,
                    recordedAt: now
                )
            )
        }
        try save()
    }

    func addTask(
        goalId: String,
        title: String,
        date: ISODate?,
        priority: String? = nil,
        notes: String? = nil
    ) throws {
        context.insert(
            OneOffTaskRecord(
                id: makeId("task"),
                goalId: goalId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                completed: false,
                date: date?.isEmpty == true ? nil : date,
                createdAt: nowString(),
                completedAt: nil,
                priority: priority,
                notes: notes
            )
        )
        try save()
    }

    func toggleTask(_ taskId: String, completed: Bool) throws {
        guard let task = try findTask(taskId) else {
            return
        }
        task.completed = completed
        task.completedAt = completed ? nowString() : nil
        try save()
    }

    func deleteTask(_ taskId: String) throws {
        if let task = try findTask(taskId) {
            context.delete(task)
            try save()
        }
    }

    func markReminderSent(date: ISODate) throws {
        let meta = try ensureMeta()
        meta.lastReminderDate = date
        try save()
    }

    func importWebState(_ state: WebAppStateV1) throws {
        for snapshot in state.goals {
            if let record = try findGoal(snapshot.id) {
                record.apply(snapshot)
            } else {
                context.insert(GoalRecord(snapshot: snapshot))
            }
        }
        for snapshot in state.routines {
            if let record = try findRoutine(snapshot.id) {
                record.apply(snapshot)
            } else {
                context.insert(RoutineRecord(snapshot: snapshot))
            }
        }
        for snapshot in state.tasks {
            if let record = try findTask(snapshot.id) {
                record.apply(snapshot)
            } else {
                context.insert(OneOffTaskRecord(snapshot: snapshot))
            }
        }
        for snapshot in state.checkIns {
            if let record = try findCheckIn(snapshot.id) {
                record.apply(snapshot)
            } else {
                context.insert(CheckInRecord(snapshot: snapshot))
            }
        }
        let meta = try ensureMeta()
        meta.lastReminderDate = state.lastReminderDate
        meta.importedWebStateAt = nowString()
        try save()
    }

    func exportWebState() throws -> Data {
        try snapshot().webState.encode()
    }

    func exportWebBackup() throws -> Data {
        try snapshot().webState.backupData(exportedAt: nowString())
    }

    private func fetchGoals() throws -> [GoalRecord] {
        try context.fetch(FetchDescriptor<GoalRecord>())
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func fetchRoutines() throws -> [RoutineRecord] {
        try context.fetch(FetchDescriptor<RoutineRecord>())
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func fetchTasks() throws -> [OneOffTaskRecord] {
        try context.fetch(FetchDescriptor<OneOffTaskRecord>())
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func fetchCheckIns() throws -> [CheckInRecord] {
        try context.fetch(FetchDescriptor<CheckInRecord>())
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    private func ensureMeta() throws -> AppMetaRecord {
        if let meta = try context.fetch(FetchDescriptor<AppMetaRecord>()).first {
            return meta
        }
        let meta = AppMetaRecord()
        context.insert(meta)
        try save()
        return meta
    }

    private func findGoal(_ id: String) throws -> GoalRecord? {
        try fetchGoals().first { $0.id == id }
    }

    private func findRoutine(_ id: String) throws -> RoutineRecord? {
        try fetchRoutines().first { $0.id == id }
    }

    private func findTask(_ id: String) throws -> OneOffTaskRecord? {
        try fetchTasks().first { $0.id == id }
    }

    private func findCheckIn(_ id: String) throws -> CheckInRecord? {
        try fetchCheckIns().first { $0.id == id }
    }

    private func save() throws {
        try context.save()
    }
}

private extension RoutineRecord {
    func applyFrequencyFromRepository(_ frequency: RoutineFrequency) {
        switch normalizedFrequency(frequency) {
        case .daily:
            frequencyType = "daily"
            timesPerWeek = 1
        case .weeklyCount(let count):
            frequencyType = "weeklyCount"
            timesPerWeek = count
        }
    }
}

private func makeId(_ prefix: String) -> String {
    "\(prefix)-\(UUID().uuidString)"
}

private func nowString() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: Date())
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
