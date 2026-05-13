import Foundation

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

public func todayISO(now: Date = Date()) -> ISODate {
    formatDate(now)
}

public func formatDate(_ date: Date) -> ISODate {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let year = components.year ?? 1970
    let month = components.month ?? 1
    let day = components.day ?? 1
    return String(format: "%04d-%02d-%02d", year, month, day)
}

public func daysBetweenInclusive(start: ISODate, end: ISODate) -> Int {
    guard end >= start, let startDate = parseDate(start), let endDate = parseDate(end) else {
        return 0
    }
    let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    return days + 1
}

public func backfillDates(through today: ISODate) -> [ISODate] {
    guard let start = parseDate(today) else {
        return []
    }
    return (0..<7).compactMap { offset in
        calendar.date(byAdding: .day, value: -offset, to: start).map(formatDate)
    }
}

public func frequencyLabel(_ frequency: RoutineFrequency) -> String {
    switch frequency {
    case .daily:
        return "每日"
    case .weeklyCount(let timesPerWeek):
        return "每周 \(normalizedWeeklyCount(timesPerWeek)) 次"
    }
}

public func buildCheckInItems(
    goals: [GoalSnapshot],
    routines: [RoutineSnapshot],
    checkIns: [CheckInSnapshot],
    date: ISODate
) -> [CheckInItem] {
    let activeGoals = Dictionary(
        uniqueKeysWithValues: goals
            .filter { $0.status == .active }
            .map { ($0.id, $0) }
    )

    return routines
        .filter { activeGoals[$0.goalId] != nil }
        .filter { shouldShowRoutineForDate($0, checkIns: checkIns, date: date) }
        .compactMap { routine in
            guard let goal = activeGoals[routine.goalId] else {
                return nil
            }
            return CheckInItem(
                routineId: routine.id,
                routineTitle: routine.title,
                goalId: goal.id,
                goalTitle: goal.title,
                frequencyLabel: frequencyLabel(routine.frequency),
                completed: isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: date)
            )
        }
}

public func buildTodayRouteItems(
    goals: [GoalSnapshot],
    routines: [RoutineSnapshot],
    tasks: [OneOffTaskSnapshot],
    checkIns: [CheckInSnapshot],
    date: ISODate
) -> [TodayRouteItem] {
    let activeGoals = Dictionary(
        uniqueKeysWithValues: goals
            .filter { $0.status == .active }
            .map { ($0.id, $0) }
    )

    return routines
        .filter { activeGoals[$0.goalId] != nil }
        .compactMap { routine in
            guard let goal = activeGoals[routine.goalId] else {
                return nil
            }

            let completedToday = isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: date)
            let status: TodayRouteStatus
            let weeklyCompletedCount: Int?
            let weeklyTarget: Int?

            switch routine.frequency {
            case .daily:
                status = completedToday ? .completedToday : .available
                weeklyCompletedCount = nil
                weeklyTarget = nil
            case .weeklyCount(let timesPerWeek):
                let normalizedTarget = normalizedWeeklyCount(timesPerWeek)
                let completedThisWeek = getWeeklyCompletionCount(routine, checkIns: checkIns, date: date)
                weeklyCompletedCount = completedThisWeek
                weeklyTarget = normalizedTarget
                if completedToday {
                    status = .completedToday
                } else if completedThisWeek >= normalizedTarget {
                    status = .weeklySatisfied
                } else {
                    status = .available
                }
            }

            return TodayRouteItem(
                routineId: routine.id,
                routineTitle: routine.title,
                goalId: goal.id,
                goalTitle: goal.title,
                frequencyLabel: frequencyLabel(routine.frequency),
                status: status,
                completedToday: completedToday,
                weeklyCompletedCount: weeklyCompletedCount,
                weeklyTarget: weeklyTarget
            )
        }
}

public func calculateGoalStats(
    goal: GoalSnapshot,
    routines: [RoutineSnapshot],
    tasks: [OneOffTaskSnapshot],
    checkIns: [CheckInSnapshot],
    today: ISODate
) -> GoalStats {
    let goalRoutines = routines.filter { $0.goalId == goal.id }
    let routineIds = Set(goalRoutines.map(\.id))
    let completedGoalCheckIns = checkIns.filter { routineIds.contains($0.routineId) && $0.completed }
    let statsToday = goal.status == .completed ? goal.completedAt?.prefix(10).description ?? today : today
    let statsEnd = statsToday < goal.startDate ? goal.startDate : statsToday
    let daysStarted = daysBetweenInclusive(start: goal.startDate, end: statsEnd)
    let dueCheckIns = goalRoutines.reduce(0) { sum, routine in
        sum + dueCountForRoutine(routine, start: goal.startDate, end: statsEnd)
    }
    let goalTasks = tasks.filter { $0.goalId == goal.id }
    let daysRemaining = goal.dueDate.map { dueDate in
        max(0, daysBetweenInclusive(start: today, end: dueDate) - 1)
    }

    return GoalStats(
        daysStarted: daysStarted,
        daysRemaining: daysRemaining,
        completedCheckIns: completedGoalCheckIns.count,
        dueCheckIns: dueCheckIns,
        completionRate: dueCheckIns == 0 ? 0 : Int((Double(completedGoalCheckIns.count) / Double(dueCheckIns) * 100).rounded()),
        routineCount: goalRoutines.count,
        taskCount: goalTasks.count,
        completedTaskCount: goalTasks.filter(\.completed).count
    )
}

public func calculateStreakSummary(checkIns: [CheckInSnapshot], through today: ISODate) -> StreakSummary {
    let completedDates = Set(checkIns.filter(\.completed).map(\.date))
    guard !completedDates.isEmpty else {
        return StreakSummary(currentDays: 0, bestDays: 0, completedDayCount: 0)
    }

    var currentDays = 0
    if var cursor = parseDate(today) {
        while completedDates.contains(formatDate(cursor)) {
            currentDays += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
    }

    let sortedDates = completedDates.sorted()
    var bestDays = 0
    var run = 0
    var previous: ISODate?

    for date in sortedDates {
        if let previous,
           let previousDate = parseDate(previous),
           let expected = calendar.date(byAdding: .day, value: 1, to: previousDate),
           formatDate(expected) == date {
            run += 1
        } else {
            run = 1
        }
        bestDays = max(bestDays, run)
        previous = date
    }

    return StreakSummary(
        currentDays: currentDays,
        bestDays: bestDays,
        completedDayCount: completedDates.count
    )
}

public func buildGoalHealth(
    goals: [GoalSnapshot],
    routines: [RoutineSnapshot],
    tasks: [OneOffTaskSnapshot],
    checkIns: [CheckInSnapshot],
    today: ISODate
) -> [GoalHealth] {
    goals
        .filter { $0.status == .active }
        .map { goal in
            let stats = calculateGoalStats(
                goal: goal,
                routines: routines,
                tasks: tasks,
                checkIns: checkIns,
                today: today
            )
            let pendingTasks = tasks.filter { $0.goalId == goal.id && !$0.completed }.count
            let missingRoutinePenalty = stats.routineCount == 0 ? 35 : 0
            let taskPenalty = min(20, pendingTasks * 4)
            let routineFoundationBonus = stats.routineCount > 0 ? 12 : 0
            let score = max(0, min(100, stats.completionRate + routineFoundationBonus - missingRoutinePenalty - taskPenalty))
            return GoalHealth(
                goalId: goal.id,
                title: goal.title,
                completionRate: stats.completionRate,
                routineCount: stats.routineCount,
                pendingTaskCount: pendingTasks,
                score: score
            )
        }
        .sorted {
            if $0.score == $1.score {
                return $0.title < $1.title
            }
            return $0.score < $1.score
        }
}

public func mostStableRoutine(
    routines: [RoutineSnapshot],
    checkIns: [CheckInSnapshot]
) -> StableRoutineSummary? {
    routines
        .map { routine in
            StableRoutineSummary(
                routineId: routine.id,
                title: routine.title,
                completedCount: checkIns.filter { $0.routineId == routine.id && $0.completed }.count
            )
        }
        .sorted {
            if $0.completedCount == $1.completedCount {
                return $0.title < $1.title
            }
            return $0.completedCount > $1.completedCount
        }
        .first { $0.completedCount > 0 }
}

public func shouldShowRoutineForDate(
    _ routine: RoutineSnapshot,
    checkIns: [CheckInSnapshot],
    date: ISODate
) -> Bool {
    switch routine.frequency {
    case .daily:
        return true
    case .weeklyCount(let timesPerWeek):
        return getWeeklyCompletionCount(routine, checkIns: checkIns, date: date) < normalizedWeeklyCount(timesPerWeek)
    }
}

public func isRoutineCompletedOnDate(
    _ checkIns: [CheckInSnapshot],
    routineId: String,
    date: ISODate
) -> Bool {
    checkIns.contains { $0.routineId == routineId && $0.date == date && $0.completed }
}

public func getWeeklyCompletionCount(
    _ routine: RoutineSnapshot,
    checkIns: [CheckInSnapshot],
    date: ISODate
) -> Int {
    let bounds = weekBounds(date)
    return checkIns.filter {
        $0.routineId == routine.id &&
            $0.completed &&
            $0.date >= bounds.start &&
            $0.date <= bounds.end
    }.count
}

public func canCompleteRoutineOnDate(
    _ routine: RoutineSnapshot,
    checkIns: [CheckInSnapshot],
    date: ISODate
) -> Bool {
    switch routine.frequency {
    case .daily:
        return true
    case .weeklyCount(let timesPerWeek):
        if isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: date) {
            return true
        }
        return getWeeklyCompletionCount(routine, checkIns: checkIns, date: date) < normalizedWeeklyCount(timesPerWeek)
    }
}

private func dueCountForRoutine(_ routine: RoutineSnapshot, start: ISODate, end: ISODate) -> Int {
    switch routine.frequency {
    case .daily:
        return daysBetweenInclusive(start: start, end: end)
    case .weeklyCount(let timesPerWeek):
        guard var cursor = parseDate(start) else {
            return 0
        }
        var count = 0
        while formatDate(cursor) <= end {
            let current = formatDate(cursor)
            let bounds = weekBounds(current)
            let countedStart = start > bounds.start ? start : bounds.start
            let countedEnd = end < bounds.end ? end : bounds.end
            let daysInRange = daysBetweenInclusive(start: countedStart, end: countedEnd)
            count += min(normalizedWeeklyCount(timesPerWeek), daysInRange)
            guard let next = parseDate(bounds.end).flatMap({ calendar.date(byAdding: .day, value: 1, to: $0) }) else {
                break
            }
            cursor = next
        }
        return count
    }
}

private func weekBounds(_ date: ISODate) -> (start: ISODate, end: ISODate) {
    guard let parsed = parseDate(date) else {
        return (date, date)
    }
    let weekday = calendar.component(.weekday, from: parsed)
    let offsetToMonday = weekday == 1 ? -6 : 2 - weekday
    let monday = calendar.date(byAdding: .day, value: offsetToMonday, to: parsed) ?? parsed
    let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
    return (formatDate(monday), formatDate(sunday))
}

private func parseDate(_ date: ISODate) -> Date? {
    let parts = date.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else {
        return nil
    }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}
