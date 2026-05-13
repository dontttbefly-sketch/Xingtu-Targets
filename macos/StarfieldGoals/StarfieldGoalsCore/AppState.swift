import Foundation

public typealias ISODate = String

public enum GoalStatus: String, Codable, Equatable, Sendable {
    case active
    case completed
}

public enum RoutineFrequency: Codable, Equatable, Sendable {
    case daily
    case weeklyCount(timesPerWeek: Int)

    private enum CodingKeys: String, CodingKey {
        case type
        case timesPerWeek
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "daily":
            self = .daily
        case "weeklyCount":
            let rawCount = try container.decodeIfPresent(Int.self, forKey: .timesPerWeek) ?? 1
            self = .weeklyCount(timesPerWeek: Self.clampWeeklyCount(rawCount))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported routine frequency type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .daily:
            try container.encode("daily", forKey: .type)
        case let .weeklyCount(timesPerWeek):
            try container.encode("weeklyCount", forKey: .type)
            try container.encode(Self.clampWeeklyCount(timesPerWeek), forKey: .timesPerWeek)
        }
    }

    public var weeklyTarget: Int? {
        guard case let .weeklyCount(timesPerWeek) = self else {
            return nil
        }
        return Self.clampWeeklyCount(timesPerWeek)
    }

    public var displayName: String {
        switch self {
        case .daily:
            return "每日"
        case let .weeklyCount(timesPerWeek):
            return "每周 \(Self.clampWeeklyCount(timesPerWeek)) 次"
        }
    }

    private static func clampWeeklyCount(_ value: Int) -> Int {
        min(7, max(1, value))
    }
}

public struct Goal: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var startDate: ISODate
    public var dueDate: ISODate?
    public var status: GoalStatus
    public var completedAt: String?
    public var createdAt: String
    public var updatedAt: String

    public init(
        id: String,
        title: String,
        startDate: ISODate,
        dueDate: ISODate?,
        status: GoalStatus,
        completedAt: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.dueDate = dueDate
        self.status = status
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Routine: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var goalId: String
    public var title: String
    public var frequency: RoutineFrequency
    public var createdAt: String
    public var updatedAt: String

    public init(
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
        self.frequency = frequency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct OneOffTask: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var goalId: String
    public var title: String
    public var completed: Bool
    public var date: ISODate?
    public var createdAt: String
    public var completedAt: String?

    public init(
        id: String,
        goalId: String,
        title: String,
        completed: Bool,
        date: ISODate?,
        createdAt: String,
        completedAt: String?
    ) {
        self.id = id
        self.goalId = goalId
        self.title = title
        self.completed = completed
        self.date = date
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public struct CheckIn: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var routineId: String
    public var date: ISODate
    public var completed: Bool
    public var recordedAt: String

    public init(id: String, routineId: String, date: ISODate, completed: Bool, recordedAt: String) {
        self.id = id
        self.routineId = routineId
        self.date = date
        self.completed = completed
        self.recordedAt = recordedAt
    }
}

public struct AppState: Codable, Equatable, Sendable {
    public var version: Int
    public var goals: [Goal]
    public var routines: [Routine]
    public var tasks: [OneOffTask]
    public var checkIns: [CheckIn]
    public var lastReminderDate: ISODate?

    public static let empty = AppState(
        version: 1,
        goals: [],
        routines: [],
        tasks: [],
        checkIns: [],
        lastReminderDate: nil
    )

    private enum CodingKeys: String, CodingKey {
        case version
        case goals
        case routines
        case tasks
        case checkIns
        case lastReminderDate
    }

    public init(
        version: Int,
        goals: [Goal],
        routines: [Routine],
        tasks: [OneOffTask],
        checkIns: [CheckIn],
        lastReminderDate: ISODate?
    ) {
        self.version = version
        self.goals = goals
        self.routines = routines
        self.tasks = tasks
        self.checkIns = checkIns
        self.lastReminderDate = lastReminderDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        goals = try container.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        routines = try container.decodeIfPresent([Routine].self, forKey: .routines) ?? []
        tasks = try container.decodeIfPresent([OneOffTask].self, forKey: .tasks) ?? []
        checkIns = try container.decodeIfPresent([CheckIn].self, forKey: .checkIns) ?? []
        lastReminderDate = try container.decodeIfPresent(ISODate.self, forKey: .lastReminderDate)
    }
}

public struct CheckInItem: Identifiable, Equatable, Sendable {
    public var id: String { routine.id }
    public var goal: Goal
    public var routine: Routine
    public var completed: Bool
    public var canComplete: Bool

    public init(goal: Goal, routine: Routine, completed: Bool, canComplete: Bool) {
        self.goal = goal
        self.routine = routine
        self.completed = completed
        self.canComplete = canComplete
    }
}

public struct TodayTaskItem: Identifiable, Equatable, Sendable {
    public var id: String { task.id }
    public var goal: Goal
    public var task: OneOffTask

    public init(goal: Goal, task: OneOffTask) {
        self.goal = goal
        self.task = task
    }
}

public struct TodayAgenda: Equatable, Sendable {
    public var routineItems: [CheckInItem]
    public var taskItems: [TodayTaskItem]
    public var progress: TodayProgress

    public init(routineItems: [CheckInItem], taskItems: [TodayTaskItem], progress: TodayProgress) {
        self.routineItems = routineItems
        self.taskItems = taskItems
        self.progress = progress
    }
}

public struct GoalStats: Equatable, Sendable {
    public var daysStarted: Int
    public var daysRemaining: Int?
    public var completedCheckIns: Int
    public var dueCheckIns: Int
    public var completionRate: Int
    public var completedTasks: Int
    public var totalTasks: Int

    public init(
        daysStarted: Int,
        daysRemaining: Int?,
        completedCheckIns: Int,
        dueCheckIns: Int,
        completionRate: Int,
        completedTasks: Int,
        totalTasks: Int
    ) {
        self.daysStarted = daysStarted
        self.daysRemaining = daysRemaining
        self.completedCheckIns = completedCheckIns
        self.dueCheckIns = dueCheckIns
        self.completionRate = completionRate
        self.completedTasks = completedTasks
        self.totalTasks = totalTasks
    }
}
