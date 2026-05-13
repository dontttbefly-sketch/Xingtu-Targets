import Foundation
import SwiftData

@Model
final class GoalRecord {
    var id: String = ""
    var title: String = ""
    var startDate: String = ""
    var dueDate: String?
    var statusRaw: String = GoalStatus.active.rawValue
    var completedAt: String?
    var createdAt: String = ""
    var updatedAt: String = ""
    var colorHex: String?
    var symbolName: String?
    var domain: String?
    var sortOrder: Int?

    init(
        id: String,
        title: String,
        startDate: String,
        dueDate: String?,
        status: GoalStatus,
        completedAt: String?,
        createdAt: String,
        updatedAt: String,
        colorHex: String? = nil,
        symbolName: String? = nil,
        domain: String? = nil,
        sortOrder: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.dueDate = dueDate
        self.statusRaw = status.rawValue
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.domain = domain
        self.sortOrder = sortOrder
    }

    convenience init(snapshot: GoalSnapshot) {
        self.init(
            id: snapshot.id,
            title: snapshot.title,
            startDate: snapshot.startDate,
            dueDate: snapshot.dueDate,
            status: snapshot.status,
            completedAt: snapshot.completedAt,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt,
            colorHex: snapshot.colorHex,
            symbolName: snapshot.symbolName,
            domain: snapshot.domain,
            sortOrder: snapshot.sortOrder
        )
    }

    var snapshot: GoalSnapshot {
        GoalSnapshot(
            id: id,
            title: title,
            startDate: startDate,
            dueDate: dueDate,
            status: GoalStatus(rawValue: statusRaw) ?? .active,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            colorHex: colorHex,
            symbolName: symbolName,
            domain: domain,
            sortOrder: sortOrder
        )
    }

    func apply(_ snapshot: GoalSnapshot) {
        title = snapshot.title
        startDate = snapshot.startDate
        dueDate = snapshot.dueDate
        statusRaw = snapshot.status.rawValue
        completedAt = snapshot.completedAt
        createdAt = snapshot.createdAt
        updatedAt = snapshot.updatedAt
        colorHex = snapshot.colorHex
        symbolName = snapshot.symbolName
        domain = snapshot.domain
        sortOrder = snapshot.sortOrder
    }
}

@Model
final class RoutineRecord {
    var id: String = ""
    var goalId: String = ""
    var title: String = ""
    var frequencyType: String = "daily"
    var timesPerWeek: Int = 1
    var createdAt: String = ""
    var updatedAt: String = ""
    var reminderTime: String?
    var preferredWeekdaysRaw: String?

    init(
        id: String,
        goalId: String,
        title: String,
        frequency: RoutineFrequency,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.goalId = goalId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        applyFrequency(frequency)
    }

    convenience init(snapshot: RoutineSnapshot) {
        self.init(
            id: snapshot.id,
            goalId: snapshot.goalId,
            title: snapshot.title,
            frequency: snapshot.frequency,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        )
    }

    var frequency: RoutineFrequency {
        frequencyType == "weeklyCount" ? .weeklyCount(timesPerWeek: timesPerWeek) : .daily
    }

    var snapshot: RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            goalId: goalId,
            title: title,
            frequency: frequency,
            createdAt: createdAt,
            updatedAt: updatedAt,
            reminderTime: reminderTime,
            preferredWeekdays: preferredWeekdays
        )
    }

    func apply(_ snapshot: RoutineSnapshot) {
        goalId = snapshot.goalId
        title = snapshot.title
        applyFrequency(snapshot.frequency)
        createdAt = snapshot.createdAt
        updatedAt = snapshot.updatedAt
        reminderTime = snapshot.reminderTime
        preferredWeekdays = snapshot.preferredWeekdays
    }

    private var preferredWeekdays: [Int]? {
        get {
            guard let preferredWeekdaysRaw, !preferredWeekdaysRaw.isEmpty else {
                return nil
            }
            return preferredWeekdaysRaw
                .split(separator: ",")
                .compactMap { Int($0) }
        }
        set {
            preferredWeekdaysRaw = newValue?.map(String.init).joined(separator: ",")
        }
    }

    private func applyFrequency(_ frequency: RoutineFrequency) {
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

@Model
final class OneOffTaskRecord {
    var id: String = ""
    var goalId: String = ""
    var title: String = ""
    var completed: Bool = false
    var date: String?
    var createdAt: String = ""
    var completedAt: String?
    var priority: String?
    var notes: String?

    init(
        id: String,
        goalId: String,
        title: String,
        completed: Bool,
        date: String?,
        createdAt: String,
        completedAt: String?,
        priority: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.title = title
        self.completed = completed
        self.date = date
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.priority = priority
        self.notes = notes
    }

    convenience init(snapshot: OneOffTaskSnapshot) {
        self.init(
            id: snapshot.id,
            goalId: snapshot.goalId,
            title: snapshot.title,
            completed: snapshot.completed,
            date: snapshot.date,
            createdAt: snapshot.createdAt,
            completedAt: snapshot.completedAt,
            priority: snapshot.priority,
            notes: snapshot.notes
        )
    }

    var snapshot: OneOffTaskSnapshot {
        OneOffTaskSnapshot(
            id: id,
            goalId: goalId,
            title: title,
            completed: completed,
            date: date,
            createdAt: createdAt,
            completedAt: completedAt,
            priority: priority,
            notes: notes
        )
    }

    func apply(_ snapshot: OneOffTaskSnapshot) {
        goalId = snapshot.goalId
        title = snapshot.title
        completed = snapshot.completed
        date = snapshot.date
        createdAt = snapshot.createdAt
        completedAt = snapshot.completedAt
        priority = snapshot.priority
        notes = snapshot.notes
    }
}

@Model
final class CheckInRecord {
    var id: String = ""
    var routineId: String = ""
    var date: String = ""
    var completed: Bool = false
    var recordedAt: String = ""
    var mood: String?
    var notes: String?

    init(
        id: String,
        routineId: String,
        date: String,
        completed: Bool,
        recordedAt: String,
        mood: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.routineId = routineId
        self.date = date
        self.completed = completed
        self.recordedAt = recordedAt
        self.mood = mood
        self.notes = notes
    }

    convenience init(snapshot: CheckInSnapshot) {
        self.init(
            id: snapshot.id,
            routineId: snapshot.routineId,
            date: snapshot.date,
            completed: snapshot.completed,
            recordedAt: snapshot.recordedAt
        )
    }

    var snapshot: CheckInSnapshot {
        CheckInSnapshot(
            id: id,
            routineId: routineId,
            date: date,
            completed: completed,
            recordedAt: recordedAt,
            mood: mood,
            notes: notes
        )
    }

    func apply(_ snapshot: CheckInSnapshot) {
        routineId = snapshot.routineId
        date = snapshot.date
        completed = snapshot.completed
        recordedAt = snapshot.recordedAt
        mood = snapshot.mood
        notes = snapshot.notes
    }
}

@Model
final class AppMetaRecord {
    var id: String = "singleton"
    var schemaVersion: Int = 1
    var lastReminderDate: String?
    var importedWebStateAt: String?
    var firstLaunchAt: String?
    var lastOpenedAt: String?

    init(
        id: String = "singleton",
        schemaVersion: Int = 1,
        lastReminderDate: String? = nil,
        importedWebStateAt: String? = nil,
        firstLaunchAt: String? = nil,
        lastOpenedAt: String? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.lastReminderDate = lastReminderDate
        self.importedWebStateAt = importedWebStateAt
        self.firstLaunchAt = firstLaunchAt
        self.lastOpenedAt = lastOpenedAt
    }

    var snapshot: AppMetaSnapshot {
        AppMetaSnapshot(
            schemaVersion: schemaVersion,
            lastReminderDate: lastReminderDate,
            importedWebStateAt: importedWebStateAt,
            firstLaunchAt: firstLaunchAt,
            lastOpenedAt: lastOpenedAt
        )
    }
}
