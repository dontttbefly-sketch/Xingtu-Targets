import Foundation
import StarfieldGoalsCore

private enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

private let goal = GoalSnapshot(
    id: "goal-1",
    title: "写完一本书",
    startDate: "2026-05-01",
    dueDate: "2026-05-31",
    status: .active,
    completedAt: nil,
    createdAt: "2026-05-01T08:00:00.000Z",
    updatedAt: "2026-05-01T08:00:00.000Z",
    colorHex: "#FFD36A",
    symbolName: "book.fill",
    domain: "创作",
    sortOrder: 0
)

private let dailyRoutine = RoutineSnapshot(
    id: "routine-daily",
    goalId: "goal-1",
    title: "写 500 字",
    frequency: .daily,
    createdAt: "2026-05-01T08:00:00.000Z",
    updatedAt: "2026-05-01T08:00:00.000Z"
)

private let weeklyRoutine = RoutineSnapshot(
    id: "routine-weekly",
    goalId: "goal-1",
    title: "长篇复盘",
    frequency: .weeklyCount(timesPerWeek: 2),
    createdAt: "2026-05-01T08:00:00.000Z",
    updatedAt: "2026-05-01T08:00:00.000Z"
)

private func runDomainChecks() throws {
    try expect(daysBetweenInclusive(start: "2026-05-01", end: "2026-05-10") == 10, "inclusive day count")
    try expect(
        backfillDates(through: "2026-05-10") == [
            "2026-05-10",
            "2026-05-09",
            "2026-05-08",
            "2026-05-07",
            "2026-05-06",
            "2026-05-05",
            "2026-05-04"
        ],
        "seven day backfill window"
    )

    let dailyItems = buildCheckInItems(
        goals: [goal],
        routines: [dailyRoutine],
        checkIns: [],
        date: "2026-05-10"
    )
    try expect(dailyItems.count == 1, "daily routine should show")
    try expect(dailyItems.first?.routineId == "routine-daily", "daily routine id")
    try expect(dailyItems.first?.goalTitle == "写完一本书", "daily routine goal title")
    try expect(dailyItems.first?.completed == false, "daily routine starts incomplete")

    let metWeeklyTarget = [
        CheckInSnapshot(
            id: "check-1",
            routineId: "routine-weekly",
            date: "2026-05-04",
            completed: true,
            recordedAt: "2026-05-04T21:00:00.000Z"
        ),
        CheckInSnapshot(
            id: "check-2",
            routineId: "routine-weekly",
            date: "2026-05-07",
            completed: true,
            recordedAt: "2026-05-07T21:00:00.000Z"
        )
    ]
    try expect(
        buildCheckInItems(goals: [goal], routines: [weeklyRoutine], checkIns: metWeeklyTarget, date: "2026-05-10").isEmpty,
        "weekly routine hides after target met"
    )

    let routeItems = buildTodayRouteItems(
        goals: [goal],
        routines: [dailyRoutine, weeklyRoutine],
        tasks: [],
        checkIns: metWeeklyTarget,
        date: "2026-05-10"
    )
    try expect(routeItems.count == 2, "today route keeps all active routines visible")
    try expect(
        routeItems.first(where: { $0.routineId == "routine-weekly" })?.status == .weeklySatisfied,
        "today route shows weekly routine as satisfied instead of hiding it"
    )
    try expect(
        routeItems.first(where: { $0.routineId == "routine-daily" })?.status == .available,
        "today route marks incomplete daily routine as available"
    )

    let stats = calculateGoalStats(
        goal: goal,
        routines: [dailyRoutine, weeklyRoutine],
        tasks: [],
        checkIns: [
            CheckInSnapshot(
                id: "check-1",
                routineId: "routine-daily",
                date: "2026-05-01",
                completed: true,
                recordedAt: "2026-05-01T21:00:00.000Z"
            ),
            CheckInSnapshot(
                id: "check-2",
                routineId: "routine-weekly",
                date: "2026-05-04",
                completed: true,
                recordedAt: "2026-05-04T21:00:00.000Z"
            )
        ],
        today: "2026-05-10"
    )
    try expect(stats.daysStarted == 10, "stats days started")
    try expect(stats.daysRemaining == 21, "stats days remaining")
    try expect(stats.completedCheckIns == 2, "stats completed check-ins")
    try expect(stats.dueCheckIns == 14, "stats due check-ins")
    try expect(stats.completionRate == 14, "stats completion rate")

    try expect(
        canCompleteRoutineOnDate(weeklyRoutine, checkIns: metWeeklyTarget, date: "2026-05-07"),
        "existing weekly completion can be toggled"
    )
    try expect(
        !canCompleteRoutineOnDate(weeklyRoutine, checkIns: metWeeklyTarget, date: "2026-05-10"),
        "new weekly completion blocked after target met"
    )

    let streak = calculateStreakSummary(
        checkIns: [
            CheckInSnapshot(id: "s-1", routineId: "routine-daily", date: "2026-05-10", completed: true, recordedAt: "2026-05-10T21:00:00.000Z"),
            CheckInSnapshot(id: "s-2", routineId: "routine-daily", date: "2026-05-09", completed: true, recordedAt: "2026-05-09T21:00:00.000Z"),
            CheckInSnapshot(id: "s-3", routineId: "routine-daily", date: "2026-05-07", completed: true, recordedAt: "2026-05-07T21:00:00.000Z")
        ],
        through: "2026-05-10"
    )
    try expect(streak.currentDays == 2, "streak counts consecutive completed days through today")
    try expect(streak.bestDays == 2, "streak tracks best completed-day run")

    let healthiest = goal
    let struggling = GoalSnapshot(
        id: "goal-2",
        title: "练体能",
        startDate: "2026-05-01",
        dueDate: nil,
        status: .active,
        completedAt: nil,
        createdAt: "2026-05-01T08:00:00.000Z",
        updatedAt: "2026-05-01T08:00:00.000Z"
    )
    let health = buildGoalHealth(
        goals: [healthiest, struggling],
        routines: [dailyRoutine],
        tasks: [],
        checkIns: [],
        today: "2026-05-10"
    )
    try expect(health.first?.goalId == "goal-2", "goal health surfaces the goal needing attention first")

    let stable = mostStableRoutine(
        routines: [dailyRoutine, weeklyRoutine],
        checkIns: [
            CheckInSnapshot(id: "stable-1", routineId: "routine-daily", date: "2026-05-08", completed: true, recordedAt: "2026-05-08T21:00:00.000Z"),
            CheckInSnapshot(id: "stable-2", routineId: "routine-daily", date: "2026-05-09", completed: true, recordedAt: "2026-05-09T21:00:00.000Z"),
            CheckInSnapshot(id: "stable-3", routineId: "routine-weekly", date: "2026-05-10", completed: true, recordedAt: "2026-05-10T21:00:00.000Z")
        ]
    )
    try expect(stable?.routineId == "routine-daily", "most stable routine chooses the highest completed count")
}

private func runImportExportChecks() throws {
    let json = """
    {
      "version": 1,
      "goals": [
        {
          "id": "goal-1",
          "title": "完成作品集",
          "startDate": "2026-05-01",
          "dueDate": "2026-05-31",
          "status": "active",
          "createdAt": "2026-05-01T08:00:00.000Z",
          "updatedAt": "2026-05-01T08:00:00.000Z"
        }
      ],
      "routines": [
        {
          "id": "routine-1",
          "goalId": "goal-1",
          "title": "每天整理一个案例",
          "frequency": { "type": "daily" },
          "createdAt": "2026-05-01T08:00:00.000Z",
          "updatedAt": "2026-05-01T08:00:00.000Z"
        }
      ],
      "tasks": [
        {
          "id": "task-1",
          "goalId": "goal-1",
          "title": "整理提纲",
          "completed": false,
          "date": "2026-05-10",
          "createdAt": "2026-05-01T08:00:00.000Z"
        }
      ],
      "checkIns": [
        {
          "id": "check-1",
          "routineId": "routine-1",
          "date": "2026-05-10",
          "completed": true,
          "recordedAt": "2026-05-10T21:00:00.000Z"
        }
      ],
      "lastReminderDate": "2026-05-10"
    }
    """

    let state = try WebAppStateV1.decode(Data(json.utf8))
    try expect(state.version == 1, "web state version")
    try expect(state.goals.first?.title == "完成作品集", "web state goal title")
    try expect(state.goals.first?.colorHex == nil, "legacy web state can omit iOS goal appearance")
    try expect(state.routines.first?.frequency == .daily, "web state daily frequency")
    try expect(state.tasks.first?.date == "2026-05-10", "web state task date")
    try expect(state.checkIns.first?.completed == true, "web state check-in completion")
    try expect(state.lastReminderDate == "2026-05-10", "web state reminder date")
    let compatibleBareState = try WebAppStateV1.decodeCompatible(Data(json.utf8))
    try expect(compatibleBareState.goals.count == 1, "compatible bare app state import")

    do {
        _ = try WebAppStateV1.decode(Data(#"{ "version": 2, "goals": [], "routines": [], "tasks": [], "checkIns": [] }"#.utf8))
        throw CheckFailure.failed("unsupported version should throw")
    } catch WebAppStateError.unsupportedVersion(let version) {
        try expect(version == 2, "unsupported version value")
    }

    let encodedState = WebAppStateV1(
        version: 1,
        goals: [
            GoalSnapshot(
                id: "goal-appearance",
                title: "可视化目标",
                startDate: "2026-05-01",
                dueDate: nil,
                status: .active,
                completedAt: nil,
                createdAt: "2026-05-01T08:00:00.000Z",
                updatedAt: "2026-05-01T08:00:00.000Z",
                colorHex: "#8EE6FF",
                symbolName: "paintpalette.fill",
                domain: "设计",
                sortOrder: 3
            )
        ],
        routines: [
            RoutineSnapshot(
                id: "routine-weekly",
                goalId: "goal-1",
                title: "长篇复盘",
                frequency: .weeklyCount(timesPerWeek: 2),
                createdAt: "2026-05-01T08:00:00.000Z",
                updatedAt: "2026-05-01T08:00:00.000Z"
            )
        ],
        tasks: [],
        checkIns: [],
        lastReminderDate: nil
    )
    let decoded = try JSONSerialization.jsonObject(with: encodedState.encode()) as? [String: Any]
    let goals = decoded?["goals"] as? [[String: Any]]
    try expect(goals?.first?["colorHex"] as? String == "#8EE6FF", "goal appearance color exports")
    try expect(goals?.first?["symbolName"] as? String == "paintpalette.fill", "goal appearance symbol exports")
    try expect(goals?.first?["domain"] as? String == "设计", "goal domain exports")
    let routines = decoded?["routines"] as? [[String: Any]]
    let frequency = routines?.first?["frequency"] as? [String: Any]
    try expect(frequency?["type"] as? String == "weeklyCount", "weekly frequency type")
    try expect(frequency?["timesPerWeek"] as? Int == 2, "weekly frequency count")

    let wrappedPayload = try encodedState.backupData(exportedAt: "2026-05-10T21:00:00.000Z")
    let wrappedObject = try JSONSerialization.jsonObject(with: wrappedPayload) as? [String: Any]
    try expect(wrappedObject?["app"] as? String == WebBackupPayloadV1.appId, "backup app id")
    try expect(wrappedObject?["schemaVersion"] as? Int == WebBackupPayloadV1.schemaVersion, "backup schema version")
    try expect(wrappedObject?["exportedAt"] as? String == "2026-05-10T21:00:00.000Z", "backup exported timestamp")
    let wrappedState = wrappedObject?["state"] as? [String: Any]
    try expect(wrappedState?["version"] as? Int == 1, "backup wrapped state version")

    let decodedPayload = try WebBackupPayloadV1.decode(wrappedPayload)
    try expect(decodedPayload.state.routines.first?.id == "routine-weekly", "backup payload state")
    let compatibleWrappedState = try WebAppStateV1.decodeCompatible(wrappedPayload)
    try expect(compatibleWrappedState.routines.first?.frequency == .weeklyCount(timesPerWeek: 2), "compatible wrapped import")
}

private func runWorkspaceChecks() throws {
    var panel = WorkspacePanel.none
    try expect(panel == .none, "workspace starts without a persistent panel")

    panel = .goalDetail(goalId: "goal-1")
    try expect(panel.focusedGoalId == "goal-1", "goal detail keeps selected goal focus")
    try expect(panel.isDrawerPresented, "goal detail uses drawer presentation")

    panel = .routineQuick(routineId: "routine-1", goalId: "goal-1")
    try expect(panel.focusedGoalId == "goal-1", "routine quick panel keeps parent goal focus")
    try expect(panel.isDrawerPresented, "routine quick panel uses drawer presentation")

    panel = .review
    try expect(panel.focusedGoalId == nil, "review panel is not tied to a focused goal")
    try expect(panel.isDrawerPresented, "review uses drawer presentation")

    panel = .data
    try expect(panel.isDrawerPresented, "data vault uses drawer presentation")

    panel = .todayRoute
    try expect(panel.isDrawerPresented, "today route uses drawer presentation")

    panel = .quickAdd
    try expect(panel.isDrawerPresented, "quick add uses drawer presentation")

    panel = .search
    try expect(panel.isDrawerPresented, "search uses drawer presentation")
}

private func runMotionChecks() throws {
    let motion = StarfieldMotionProfile.silky
    try expect(motion.cameraResponse <= 0.34, "camera motion should react quickly to dragging")
    try expect(motion.cameraDampingFraction >= 0.82, "camera motion should settle without bounce")
    try expect(motion.focusResponse > motion.cameraResponse, "focus motion should feel more cinematic than camera motion")
    try expect(motion.drawerResponse >= 0.40, "drawer motion should be slower than direct manipulation")
    try expect(motion.ambientDriftDuration >= 2.6, "ambient star shimmer should be slow enough to feel calm")
    try expect(motion.pressScale < 1 && motion.pressScale >= 0.94, "pressed controls should compress subtly")

    let defaultCamera = clampedStarfieldCameraOffset(width: 180, height: -180, scale: 1)
    try expect(defaultCamera.width == 42, "default camera pan should stay inside a light parallax range")
    try expect(defaultCamera.height == -38, "default camera pan should not let stars slide under the top chrome")

    let zoomedCamera = clampedStarfieldCameraOffset(width: 180, height: -180, scale: 1.6)
    try expect(zoomedCamera.width > defaultCamera.width, "zoomed camera should allow wider exploration")
    try expect(abs(zoomedCamera.height) > abs(defaultCamera.height), "zoomed camera should allow deeper vertical exploration")
}

private func runStarfieldLayoutChecks() throws {
    let firstOverview = starfieldOverviewUnitPoint(index: 0, totalCount: 2)
    let secondOverview = starfieldOverviewUnitPoint(index: 1, totalCount: 2)
    try expect(distance(firstOverview, secondOverview) >= 0.30, "two overview stars should start visually separated")

    let triangle = (0..<3).map { starfieldOverviewUnitPoint(index: $0, totalCount: 3) }
    try expect(distance(triangle[0], triangle[1]) >= 0.24, "three-star overview keeps first and second separated")
    try expect(distance(triangle[1], triangle[2]) >= 0.24, "three-star overview keeps second and third separated")

    let completedConstellation = starfieldCompletedConstellationUnitPoint(index: 0, totalCount: 2)
    try expect(completedConstellation.x > 0.70, "completed stars should move to a distant constellation area")
    try expect(completedConstellation.y < 0.34, "completed stars should sit above the active work zone")

    let focused = starfieldFocusedUnitPoint(index: 1, selectedIndex: 1, totalCount: 2)
    let displaced = starfieldFocusedUnitPoint(index: 0, selectedIndex: 1, totalCount: 2)
    try expect(focused == StarfieldUnitPoint(x: 0.5, y: 0.30), "selected star should focus above the mobile detail drawer")
    try expect(displaced.y > focused.y, "single non-selected star should move below the focus center")
    try expect(distance(focused, displaced) >= 0.24, "two stars should stay visually separated during focus")

    let selectedFirst = starfieldFocusedUnitPoint(index: 0, selectedIndex: 0, totalCount: 2)
    let secondDisplaced = starfieldFocusedUnitPoint(index: 1, selectedIndex: 0, totalCount: 2)
    try expect(selectedFirst == StarfieldUnitPoint(x: 0.5, y: 0.30), "first star can also focus above the mobile detail drawer")
    try expect(distance(selectedFirst, secondDisplaced) >= 0.24, "second star should move away when first star is focused")
}

private func runTopChromeChecks() throws {
    let chrome = StarfieldTopChromeProfile.mobilePinned
    try expect(chrome.pinsToSafeAreaTop, "top chrome should be pinned to the safe area top")
    try expect(chrome.topContentPadding <= 8, "top chrome content should not float down into the middle")
    try expect(chrome.horizontalPadding <= 16, "top chrome should use near-edge mobile spacing")
    try expect(chrome.actionButtonSize >= 40, "top chrome actions should keep comfortable tap targets")
    try expect(chrome.metricColumns == 4, "overview metrics should fit as a compact row")
}

private func runVisualToneChecks() throws {
    let first = starfieldPlanetTone(index: 0, customHex: nil)
    let sixth = starfieldPlanetTone(index: 5, customHex: nil)
    try expect(first == sixth, "planet tone palette should cycle predictably")
    try expect(first.coreHex == "#FFD36A", "first planet tone keeps a warm anchor")
    try expect(first.shadowHex != first.coreHex, "planet tone should include real shadow contrast")
    try expect(first.atmosphereHex != first.shadowHex, "planet atmosphere should stay luminous")

    let custom = starfieldPlanetTone(index: 2, customHex: " 8ee6ff ")
    try expect(custom.coreHex == "#8EE6FF", "custom planet color should normalize hex input")
    try expect(custom.mantleHex == "#8EE6FF", "custom planet keeps user color as the main body")
    try expect(custom.shadowHex == "#151A2A", "custom planet still receives a harmonized deep shadow")

    let fallback = starfieldPlanetTone(index: 2, customHex: "#NOPE")
    try expect(fallback.coreHex == "#FF9A86", "invalid custom color should fall back to palette")
}

private func distance(_ lhs: StarfieldUnitPoint, _ rhs: StarfieldUnitPoint) -> Double {
    let dx = lhs.x - rhs.x
    let dy = lhs.y - rhs.y
    return (dx * dx + dy * dy).squareRoot()
}

do {
    try runDomainChecks()
    try runImportExportChecks()
    try runWorkspaceChecks()
    try runMotionChecks()
    try runStarfieldLayoutChecks()
    try runTopChromeChecks()
    try runVisualToneChecks()
    print("StarfieldGoalsCore checks passed")
} catch {
    fputs("StarfieldGoalsCore check failed: \(error)\n", stderr)
    exit(1)
}
