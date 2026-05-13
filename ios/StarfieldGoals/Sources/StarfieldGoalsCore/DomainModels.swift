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

    private enum FrequencyType: String, Codable {
        case daily
        case weeklyCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FrequencyType.self, forKey: .type)
        switch type {
        case .daily:
            self = .daily
        case .weeklyCount:
            let value = try container.decode(Int.self, forKey: .timesPerWeek)
            self = .weeklyCount(timesPerWeek: normalizedWeeklyCount(value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try container.encode(FrequencyType.daily, forKey: .type)
        case .weeklyCount(let timesPerWeek):
            try container.encode(FrequencyType.weeklyCount, forKey: .type)
            try container.encode(normalizedWeeklyCount(timesPerWeek), forKey: .timesPerWeek)
        }
    }
}

public struct GoalSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var startDate: ISODate
    public var dueDate: ISODate?
    public var status: GoalStatus
    public var completedAt: String?
    public var createdAt: String
    public var updatedAt: String
    public var colorHex: String?
    public var symbolName: String?
    public var domain: String?
    public var sortOrder: Int?

    public init(
        id: String,
        title: String,
        startDate: ISODate,
        dueDate: ISODate?,
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
        self.status = status
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.domain = domain
        self.sortOrder = sortOrder
    }
}

public struct RoutineSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var goalId: String
    public var title: String
    public var frequency: RoutineFrequency
    public var createdAt: String
    public var updatedAt: String
    public var reminderTime: String?
    public var preferredWeekdays: [Int]?

    public init(
        id: String,
        goalId: String,
        title: String,
        frequency: RoutineFrequency,
        createdAt: String,
        updatedAt: String,
        reminderTime: String? = nil,
        preferredWeekdays: [Int]? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.title = title
        self.frequency = normalizedFrequency(frequency)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.reminderTime = reminderTime
        self.preferredWeekdays = preferredWeekdays
    }
}

public struct OneOffTaskSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var goalId: String
    public var title: String
    public var completed: Bool
    public var date: ISODate?
    public var createdAt: String
    public var completedAt: String?
    public var priority: String?
    public var notes: String?

    public init(
        id: String,
        goalId: String,
        title: String,
        completed: Bool,
        date: ISODate?,
        createdAt: String,
        completedAt: String? = nil,
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
}

public struct CheckInSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var routineId: String
    public var date: ISODate
    public var completed: Bool
    public var recordedAt: String
    public var mood: String?
    public var notes: String?

    public init(
        id: String,
        routineId: String,
        date: ISODate,
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
}

public struct CheckInItem: Equatable, Identifiable, Sendable {
    public var id: String { routineId }
    public var routineId: String
    public var routineTitle: String
    public var goalId: String
    public var goalTitle: String
    public var frequencyLabel: String
    public var completed: Bool
}

public enum TodayRouteStatus: String, Codable, Equatable, Sendable {
    case available
    case completedToday
    case weeklySatisfied
}

public struct TodayRouteItem: Equatable, Identifiable, Sendable {
    public var id: String { routineId }
    public var routineId: String
    public var routineTitle: String
    public var goalId: String
    public var goalTitle: String
    public var frequencyLabel: String
    public var status: TodayRouteStatus
    public var completedToday: Bool
    public var weeklyCompletedCount: Int?
    public var weeklyTarget: Int?

    public init(
        routineId: String,
        routineTitle: String,
        goalId: String,
        goalTitle: String,
        frequencyLabel: String,
        status: TodayRouteStatus,
        completedToday: Bool,
        weeklyCompletedCount: Int?,
        weeklyTarget: Int?
    ) {
        self.routineId = routineId
        self.routineTitle = routineTitle
        self.goalId = goalId
        self.goalTitle = goalTitle
        self.frequencyLabel = frequencyLabel
        self.status = status
        self.completedToday = completedToday
        self.weeklyCompletedCount = weeklyCompletedCount
        self.weeklyTarget = weeklyTarget
    }
}

public struct GoalStats: Equatable, Sendable {
    public var daysStarted: Int
    public var daysRemaining: Int?
    public var completedCheckIns: Int
    public var dueCheckIns: Int
    public var completionRate: Int
    public var routineCount: Int
    public var taskCount: Int
    public var completedTaskCount: Int
}

public struct StreakSummary: Equatable, Sendable {
    public var currentDays: Int
    public var bestDays: Int
    public var completedDayCount: Int

    public init(currentDays: Int, bestDays: Int, completedDayCount: Int) {
        self.currentDays = currentDays
        self.bestDays = bestDays
        self.completedDayCount = completedDayCount
    }
}

public struct GoalHealth: Equatable, Identifiable, Sendable {
    public var id: String { goalId }
    public var goalId: String
    public var title: String
    public var completionRate: Int
    public var routineCount: Int
    public var pendingTaskCount: Int
    public var score: Int

    public init(
        goalId: String,
        title: String,
        completionRate: Int,
        routineCount: Int,
        pendingTaskCount: Int,
        score: Int
    ) {
        self.goalId = goalId
        self.title = title
        self.completionRate = completionRate
        self.routineCount = routineCount
        self.pendingTaskCount = pendingTaskCount
        self.score = score
    }
}

public struct StableRoutineSummary: Equatable, Identifiable, Sendable {
    public var id: String { routineId }
    public var routineId: String
    public var title: String
    public var completedCount: Int

    public init(routineId: String, title: String, completedCount: Int) {
        self.routineId = routineId
        self.title = title
        self.completedCount = completedCount
    }
}

public struct AppMetaSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var lastReminderDate: ISODate?
    public var importedWebStateAt: String?
    public var firstLaunchAt: String?
    public var lastOpenedAt: String?

    public init(
        schemaVersion: Int = 1,
        lastReminderDate: ISODate? = nil,
        importedWebStateAt: String? = nil,
        firstLaunchAt: String? = nil,
        lastOpenedAt: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.lastReminderDate = lastReminderDate
        self.importedWebStateAt = importedWebStateAt
        self.firstLaunchAt = firstLaunchAt
        self.lastOpenedAt = lastOpenedAt
    }
}

public enum WorkspacePanel: Equatable, Sendable {
    case none
    case todayRoute
    case goalDetail(goalId: String)
    case review
    case data
    case routineQuick(routineId: String, goalId: String)
    case quickAdd
    case search

    public var isDrawerPresented: Bool {
        self != .none
    }

    public var focusedGoalId: String? {
        switch self {
        case .none, .todayRoute, .review, .data, .quickAdd, .search:
            return nil
        case .goalDetail(let goalId):
            return goalId
        case .routineQuick(_, let goalId):
            return goalId
        }
    }
}

public struct StarfieldMotionProfile: Equatable, Sendable {
    public var cameraResponse: Double
    public var cameraDampingFraction: Double
    public var focusResponse: Double
    public var focusDampingFraction: Double
    public var drawerResponse: Double
    public var drawerDampingFraction: Double
    public var ambientDriftDuration: Double
    public var pressScale: Double

    public init(
        cameraResponse: Double,
        cameraDampingFraction: Double,
        focusResponse: Double,
        focusDampingFraction: Double,
        drawerResponse: Double,
        drawerDampingFraction: Double,
        ambientDriftDuration: Double,
        pressScale: Double
    ) {
        self.cameraResponse = cameraResponse
        self.cameraDampingFraction = cameraDampingFraction
        self.focusResponse = focusResponse
        self.focusDampingFraction = focusDampingFraction
        self.drawerResponse = drawerResponse
        self.drawerDampingFraction = drawerDampingFraction
        self.ambientDriftDuration = ambientDriftDuration
        self.pressScale = pressScale
    }

    public static let silky = StarfieldMotionProfile(
        cameraResponse: 0.30,
        cameraDampingFraction: 0.86,
        focusResponse: 0.52,
        focusDampingFraction: 0.82,
        drawerResponse: 0.44,
        drawerDampingFraction: 0.86,
        ambientDriftDuration: 3.2,
        pressScale: 0.96
    )
}

public struct StarfieldStellarTone: Equatable, Sendable {
    public var coreHex: String
    public var coronaHex: String
    public var flareHex: String
    public var haloHex: String
    public var accentHex: String

    public init(
        coreHex: String,
        coronaHex: String,
        flareHex: String,
        haloHex: String,
        accentHex: String
    ) {
        self.coreHex = coreHex
        self.coronaHex = coronaHex
        self.flareHex = flareHex
        self.haloHex = haloHex
        self.accentHex = accentHex
    }
}

private let starfieldStellarTonePalette: [StarfieldStellarTone] = [
    StarfieldStellarTone(
        coreHex: "#FFF8D6",
        coronaHex: "#FFD36A",
        flareHex: "#FFB14A",
        haloHex: "#FFE7A3",
        accentHex: "#8EE7D1"
    ),
    StarfieldStellarTone(
        coreHex: "#F4FDFF",
        coronaHex: "#8EE6FF",
        flareHex: "#5FB9FF",
        haloHex: "#9DEBFF",
        accentHex: "#BEE7D0"
    ),
    StarfieldStellarTone(
        coreHex: "#FFF1EC",
        coronaHex: "#FF8F78",
        flareHex: "#FF5F96",
        haloHex: "#FFB49E",
        accentHex: "#FFD36A"
    ),
    StarfieldStellarTone(
        coreHex: "#F2FFE8",
        coronaHex: "#A7E29A",
        flareHex: "#62D6B6",
        haloHex: "#BDECCB",
        accentHex: "#FFD36A"
    ),
    StarfieldStellarTone(
        coreHex: "#F8F0FF",
        coronaHex: "#C9A7FF",
        flareHex: "#7E89E8",
        haloHex: "#D8C5FF",
        accentHex: "#92E4D0"
    )
]

public func starfieldStellarTone(index: Int, customHex: String?) -> StarfieldStellarTone {
    if let customHex = normalizedStarfieldHex(customHex) {
        return StarfieldStellarTone(
            coreHex: "#FFFFFF",
            coronaHex: customHex,
            flareHex: customHex,
            haloHex: customHex,
            accentHex: "#BDECCB"
        )
    }

    let count = starfieldStellarTonePalette.count
    let safeIndex = ((index % count) + count) % count
    return starfieldStellarTonePalette[safeIndex]
}

private func normalizedStarfieldHex(_ value: String?) -> String? {
    guard let value else {
        return nil
    }
    let raw = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        .uppercased()
    guard raw.count == 6, UInt64(raw, radix: 16) != nil else {
        return nil
    }
    return "#\(raw)"
}

public struct StarfieldCameraOffset: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public func clampedStarfieldCameraOffset(width: Double, height: Double, scale: Double) -> StarfieldCameraOffset {
    let scaleFactor = max(0, scale - 1)
    let horizontalLimit = 42 + scaleFactor * 182
    let verticalLimit = 38 + scaleFactor * 220
    return StarfieldCameraOffset(
        width: min(horizontalLimit, max(-horizontalLimit, width)),
        height: min(verticalLimit, max(-verticalLimit, height))
    )
}

public struct StarfieldUnitPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public func starfieldOverviewUnitPoint(index: Int, totalCount: Int) -> StarfieldUnitPoint {
    let center = StarfieldUnitPoint(x: 0.5, y: 0.48)
    guard totalCount > 1 else {
        return center
    }

    if totalCount == 2 {
        return index == 0
            ? StarfieldUnitPoint(x: 0.34, y: 0.47)
            : StarfieldUnitPoint(x: 0.66, y: 0.49)
    }

    if totalCount == 3 {
        let points = [
            StarfieldUnitPoint(x: 0.50, y: 0.33),
            StarfieldUnitPoint(x: 0.30, y: 0.58),
            StarfieldUnitPoint(x: 0.70, y: 0.58)
        ]
        return points[min(index, points.count - 1)]
    }

    if totalCount == 4 {
        let points = [
            StarfieldUnitPoint(x: 0.34, y: 0.35),
            StarfieldUnitPoint(x: 0.66, y: 0.37),
            StarfieldUnitPoint(x: 0.30, y: 0.63),
            StarfieldUnitPoint(x: 0.70, y: 0.61)
        ]
        return points[min(index, points.count - 1)]
    }

    let angle = Double(index) * 2.399963
    let ring = Double(index / 5)
    let radius = 0.16 + Double(index % 5) * 0.055 + ring * 0.050
    let x = center.x + cos(angle) * radius
    let y = center.y + sin(angle) * radius * 0.82

    return StarfieldUnitPoint(
        x: min(0.84, max(0.16, x)),
        y: min(0.78, max(0.20, y))
    )
}

public func starfieldCompletedConstellationUnitPoint(index: Int, totalCount: Int) -> StarfieldUnitPoint {
    let count = max(1, totalCount)
    let angle = (Double(index) / Double(count)) * .pi * 2 - .pi / 2
    let radius = 0.055 + Double(index % 3) * 0.018
    let x = 0.78 + cos(angle) * radius
    let y = 0.25 + sin(angle) * radius * 0.72
    return StarfieldUnitPoint(
        x: min(0.90, max(0.70, x)),
        y: min(0.34, max(0.16, y))
    )
}

public func starfieldFocusedUnitPoint(index: Int, selectedIndex: Int, totalCount: Int) -> StarfieldUnitPoint {
    let center = StarfieldUnitPoint(x: 0.5, y: 0.30)
    guard totalCount > 0 else {
        return center
    }
    guard index != selectedIndex else {
        return center
    }

    let otherRank = index < selectedIndex ? index : index - 1
    let angle = Double(otherRank) * 2.399963 + Double(selectedIndex) * 0.45 + .pi * 0.32
    let x = center.x + cos(angle) * 0.32
    let y = center.y + sin(angle) * 0.28

    return StarfieldUnitPoint(
        x: min(0.84, max(0.16, x)),
        y: min(0.78, max(0.20, y))
    )
}

public struct StarfieldTopChromeProfile: Equatable, Sendable {
    public var pinsToSafeAreaTop: Bool
    public var topContentPadding: Double
    public var horizontalPadding: Double
    public var bottomPadding: Double
    public var actionButtonSize: Double
    public var metricColumns: Int

    public init(
        pinsToSafeAreaTop: Bool,
        topContentPadding: Double,
        horizontalPadding: Double,
        bottomPadding: Double,
        actionButtonSize: Double,
        metricColumns: Int
    ) {
        self.pinsToSafeAreaTop = pinsToSafeAreaTop
        self.topContentPadding = topContentPadding
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.actionButtonSize = actionButtonSize
        self.metricColumns = metricColumns
    }

    public static let mobilePinned = StarfieldTopChromeProfile(
        pinsToSafeAreaTop: true,
        topContentPadding: 6,
        horizontalPadding: 14,
        bottomPadding: 12,
        actionButtonSize: 42,
        metricColumns: 4
    )
}

public func normalizedFrequency(_ frequency: RoutineFrequency) -> RoutineFrequency {
    switch frequency {
    case .daily:
        return .daily
    case .weeklyCount(let timesPerWeek):
        return .weeklyCount(timesPerWeek: normalizedWeeklyCount(timesPerWeek))
    }
}

func normalizedWeeklyCount(_ value: Int) -> Int {
    min(7, max(1, value))
}
