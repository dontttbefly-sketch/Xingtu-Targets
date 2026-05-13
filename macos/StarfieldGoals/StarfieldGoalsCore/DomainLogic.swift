import Foundation

public struct TodayProgress: Equatable, Sendable {
    public var completed: Int
    public var total: Int
    public var remaining: Int
    public var completionRate: Int

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
        remaining = max(0, total - completed)
        completionRate = total == 0 ? 0 : min(100, Int((Double(completed) / Double(total) * 100).rounded()))
    }
}

public struct VoyageSummary: Equatable, Sendable {
    public var activeGoals: Int
    public var completedGoals: Int
    public var totalGoals: Int
    public var routines: Int
    public var completedCheckIns: Int
    public var weeklyCheckIns: Int
    public var completedTasks: Int
    public var totalTasks: Int
    public var todayProgress: TodayProgress

    public init(
        activeGoals: Int,
        completedGoals: Int,
        totalGoals: Int,
        routines: Int,
        completedCheckIns: Int,
        weeklyCheckIns: Int,
        completedTasks: Int,
        totalTasks: Int,
        todayProgress: TodayProgress
    ) {
        self.activeGoals = activeGoals
        self.completedGoals = completedGoals
        self.totalGoals = totalGoals
        self.routines = routines
        self.completedCheckIns = completedCheckIns
        self.weeklyCheckIns = weeklyCheckIns
        self.completedTasks = completedTasks
        self.totalTasks = totalTasks
        self.todayProgress = todayProgress
    }
}

public struct RoutineMomentum: Equatable, Sendable {
    public var completedTotal: Int
    public var currentDailyStreak: Int
    public var weekCompleted: Int
    public var weekTarget: Int?

    public init(
        completedTotal: Int,
        currentDailyStreak: Int,
        weekCompleted: Int,
        weekTarget: Int?
    ) {
        self.completedTotal = completedTotal
        self.currentDailyStreak = currentDailyStreak
        self.weekCompleted = weekCompleted
        self.weekTarget = weekTarget
    }
}

public enum DomainLogic {
    public static func todayISO(now: Date = Date()) -> ISODate {
        DateCoding.dateString(from: now)
    }

    public static func formatDate(_ date: Date) -> ISODate {
        DateCoding.dateString(from: date)
    }

    public static func backfillDates(through date: ISODate) -> [ISODate] {
        guard let end = DateCoding.parseDate(date) else {
            return []
        }

        let calendar = DateCoding.calendar()
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: end).map { DateCoding.dateString(from: $0) }
        }
    }

    public static func daysBetweenInclusive(start: ISODate, end: ISODate) -> Int {
        guard let startDate = DateCoding.parseDate(start),
              let endDate = DateCoding.parseDate(end) else {
            return 0
        }

        let calendar = DateCoding.calendar()
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.startOfDay(for: endDate)
        guard startOfDay <= endOfDay else {
            return 0
        }

        return (calendar.dateComponents([.day], from: startOfDay, to: endOfDay).day ?? 0) + 1
    }

    public static func frequencyLabel(_ frequency: RoutineFrequency) -> String {
        frequency.displayName
    }

    public static func isRoutineCompletedOnDate(
        _ checkIns: [CheckIn],
        routineId: String,
        date: ISODate
    ) -> Bool {
        checkIns.contains { checkIn in
            checkIn.routineId == routineId && checkIn.date == date && checkIn.completed
        }
    }

    public static func weeklyCompletionCount(
        _ routine: Routine,
        checkIns: [CheckIn],
        date: ISODate
    ) -> Int {
        guard case .weeklyCount = routine.frequency,
              let targetDate = DateCoding.parseDate(date) else {
            return 0
        }

        let interval = weekInterval(containing: targetDate)
        return checkIns.filter { checkIn in
            guard checkIn.routineId == routine.id,
                  checkIn.completed,
                  let checkInDate = DateCoding.parseDate(checkIn.date) else {
                return false
            }
            return interval.start <= checkInDate && checkInDate <= interval.end
        }.count
    }

    public static func canCompleteRoutine(
        on date: ISODate,
        routine: Routine,
        checkIns: [CheckIn]
    ) -> Bool {
        switch routine.frequency {
        case .daily:
            return true
        case let .weeklyCount(timesPerWeek):
            if isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: date) {
                return true
            }
            return weeklyCompletionCount(routine, checkIns: checkIns, date: date) < min(7, max(1, timesPerWeek))
        }
    }

    public static func shouldShowRoutineForDate(
        _ routine: Routine,
        checkIns: [CheckIn],
        date: ISODate
    ) -> Bool {
        switch routine.frequency {
        case .daily:
            return true
        case .weeklyCount:
            return canCompleteRoutine(on: date, routine: routine, checkIns: checkIns)
        }
    }

    public static func buildCheckInItems(
        goals: [Goal],
        routines: [Routine],
        checkIns: [CheckIn],
        date: ISODate
    ) -> [CheckInItem] {
        let activeGoals = goals.filter { $0.status == .active }
        return activeGoals.flatMap { goal in
            routines
                .filter { $0.goalId == goal.id }
                .filter { shouldShowRoutineForDate($0, checkIns: checkIns, date: date) }
                .map { routine in
                    CheckInItem(
                        goal: goal,
                        routine: routine,
                        completed: isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: date),
                        canComplete: canCompleteRoutine(on: date, routine: routine, checkIns: checkIns)
                    )
                }
        }
    }

    public static func todayProgress(
        goals: [Goal],
        routines: [Routine],
        checkIns: [CheckIn],
        date: ISODate
    ) -> TodayProgress {
        let items = buildCheckInItems(goals: goals, routines: routines, checkIns: checkIns, date: date)
        return TodayProgress(completed: items.filter(\.completed).count, total: items.count)
    }

    public static func todayAgenda(
        goals: [Goal],
        routines: [Routine],
        tasks: [OneOffTask],
        checkIns: [CheckIn],
        date: ISODate
    ) -> TodayAgenda {
        let routineItems = buildCheckInItems(
            goals: goals,
            routines: routines,
            checkIns: checkIns,
            date: date
        )
        let activeGoals = goals.filter { $0.status == .active }
        let activeGoalIds = Set(activeGoals.map(\.id))
        let goalById = Dictionary(uniqueKeysWithValues: activeGoals.map { ($0.id, $0) })
        let taskItems = tasks
            .filter { task in
                guard activeGoalIds.contains(task.goalId), task.completed == false else {
                    return false
                }
                guard let taskDate = task.date else {
                    return true
                }
                return taskDate <= date
            }
            .compactMap { task -> TodayTaskItem? in
                guard let goal = goalById[task.goalId] else {
                    return nil
                }
                return TodayTaskItem(goal: goal, task: task)
            }

        return TodayAgenda(
            routineItems: routineItems,
            taskItems: taskItems,
            progress: TodayProgress(completed: routineItems.filter(\.completed).count, total: routineItems.count)
        )
    }

    public static func voyageSummary(
        goals: [Goal],
        routines: [Routine],
        tasks: [OneOffTask],
        checkIns: [CheckIn],
        today: ISODate
    ) -> VoyageSummary {
        let completedCheckIns = checkIns.filter(\.completed)
        let weeklyCheckIns = completedCheckIns.filter { checkIn in
            guard let date = DateCoding.parseDate(today),
                  let checkInDate = DateCoding.parseDate(checkIn.date) else {
                return false
            }
            let week = weekInterval(containing: date)
            return week.start <= checkInDate && checkInDate <= week.end
        }.count

        return VoyageSummary(
            activeGoals: goals.filter { $0.status == .active }.count,
            completedGoals: goals.filter { $0.status == .completed }.count,
            totalGoals: goals.count,
            routines: routines.count,
            completedCheckIns: completedCheckIns.count,
            weeklyCheckIns: weeklyCheckIns,
            completedTasks: tasks.filter(\.completed).count,
            totalTasks: tasks.count,
            todayProgress: todayProgress(goals: goals, routines: routines, checkIns: checkIns, date: today)
        )
    }

    public static func routineMomentum(
        _ routine: Routine,
        checkIns: [CheckIn],
        today: ISODate
    ) -> RoutineMomentum {
        let completed = checkIns.filter { checkIn in
            checkIn.routineId == routine.id && checkIn.completed
        }
        let completedDates = Set(completed.map(\.date))

        let currentStreak: Int
        switch routine.frequency {
        case .daily:
            currentStreak = dailyStreak(endingOn: today, completedDates: completedDates)
        case .weeklyCount:
            currentStreak = 0
        }

        let weekTarget: Int?
        let weekCompleted: Int
        switch routine.frequency {
        case .daily:
            weekTarget = nil
            weekCompleted = 0
        case let .weeklyCount(timesPerWeek):
            weekTarget = min(7, max(1, timesPerWeek))
            weekCompleted = weeklyCompletionCount(routine, checkIns: checkIns, date: today)
        }

        return RoutineMomentum(
            completedTotal: completed.count,
            currentDailyStreak: currentStreak,
            weekCompleted: weekCompleted,
            weekTarget: weekTarget
        )
    }

    public static func goalStats(
        goal: Goal,
        routines: [Routine],
        tasks: [OneOffTask],
        checkIns: [CheckIn],
        today: ISODate
    ) -> GoalStats {
        let daysStarted = daysBetweenInclusive(start: goal.startDate, end: today)
        let daysRemaining = goal.dueDate.map { dueDate in
            guard let todayDate = DateCoding.parseDate(today),
                  let due = DateCoding.parseDate(dueDate) else {
                return 0
            }
            let calendar = DateCoding.calendar()
            let diff = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: todayDate),
                to: calendar.startOfDay(for: due)
            ).day ?? 0
            return max(0, diff)
        }

        let routineIds = Set(routines.filter { $0.goalId == goal.id }.map(\.id))
        let completedCheckIns = checkIns.filter { routineIds.contains($0.routineId) && $0.completed }.count
        let dueCheckIns = routines
            .filter { $0.goalId == goal.id }
            .reduce(0) { total, routine in
                total + dueCount(for: routine, startDate: goal.startDate, through: today)
            }
        let completionRate = dueCheckIns == 0 ? 0 : Int((Double(completedCheckIns) / Double(dueCheckIns) * 100).rounded())
        let goalTasks = tasks.filter { $0.goalId == goal.id }

        return GoalStats(
            daysStarted: daysStarted,
            daysRemaining: daysRemaining,
            completedCheckIns: completedCheckIns,
            dueCheckIns: dueCheckIns,
            completionRate: min(100, completionRate),
            completedTasks: goalTasks.filter(\.completed).count,
            totalTasks: goalTasks.count
        )
    }

    private static func dueCount(for routine: Routine, startDate: ISODate, through today: ISODate) -> Int {
        switch routine.frequency {
        case .daily:
            return daysBetweenInclusive(start: startDate, end: today)
        case let .weeklyCount(timesPerWeek):
            return weeklyDueCount(startDate: startDate, through: today, target: min(7, max(1, timesPerWeek)))
        }
    }

    private static func weeklyDueCount(startDate: ISODate, through today: ISODate, target: Int) -> Int {
        guard let start = DateCoding.parseDate(startDate),
              let end = DateCoding.parseDate(today),
              start <= end else {
            return 0
        }

        let calendar = DateCoding.calendar()
        var cursor = calendar.startOfDay(for: start)
        var total = 0

        while cursor <= end {
            let week = weekInterval(containing: cursor)
            let segmentStart = maxDate(start, week.start)
            let segmentEnd = minDate(end, week.end)
            let daysInSegment = max(0, (calendar.dateComponents([.day], from: segmentStart, to: segmentEnd).day ?? 0) + 1)
            total += min(target, daysInSegment)

            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: week.start) else {
                break
            }
            cursor = nextWeek
        }

        return total
    }

    private static func dailyStreak(endingOn today: ISODate, completedDates: Set<ISODate>) -> Int {
        guard let date = DateCoding.parseDate(today) else {
            return 0
        }

        let calendar = DateCoding.calendar()
        var cursor = calendar.startOfDay(for: date)
        var streak = 0

        while completedDates.contains(DateCoding.dateString(from: cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return streak
    }

    private static func weekInterval(containing date: Date) -> (start: Date, end: Date) {
        let calendar = DateCoding.calendar()
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return (weekStart, weekEnd)
    }

    private static func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }

    private static func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs < rhs ? lhs : rhs
    }
}
