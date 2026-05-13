import XCTest
@testable import StarfieldGoalsCore

final class DomainLogicTests: XCTestCase {
    func testDateStringUsesDeviceLocalDay() {
        let date = ISO8601DateFormatter().date(from: "2026-05-12T16:30:00Z")!
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!

        XCTAssertEqual(DateCoding.dateString(from: date, timeZone: shanghai), "2026-05-13")
    }

    func testBackfillDatesOfferTodayAndPreviousSixDays() {
        XCTAssertEqual(
            DomainLogic.backfillDates(through: "2026-05-11"),
            [
                "2026-05-11",
                "2026-05-10",
                "2026-05-09",
                "2026-05-08",
                "2026-05-07",
                "2026-05-06",
                "2026-05-05"
            ]
        )
    }

    func testWeeklyRoutineCannotAddExtraCompletionAfterTargetButCanCancelToday() {
        let routine = Routine(
            id: "routine-weekly",
            goalId: "goal-1",
            title: "长篇复盘",
            frequency: .weeklyCount(timesPerWeek: 2),
            createdAt: "2026-05-01T08:00:00.000Z",
            updatedAt: "2026-05-01T08:00:00.000Z"
        )
        let completedThisWeek = [
            CheckIn(id: "check-1", routineId: routine.id, date: "2026-05-04", completed: true, recordedAt: "2026-05-04T21:00:00.000Z"),
            CheckIn(id: "check-2", routineId: routine.id, date: "2026-05-07", completed: true, recordedAt: "2026-05-07T21:00:00.000Z")
        ]
        let completedToday = [
            CheckIn(id: "check-1", routineId: routine.id, date: "2026-05-04", completed: true, recordedAt: "2026-05-04T21:00:00.000Z"),
            CheckIn(id: "check-2", routineId: routine.id, date: "2026-05-11", completed: true, recordedAt: "2026-05-11T21:00:00.000Z")
        ]

        XCTAssertEqual(DomainLogic.weeklyCompletionCount(routine, checkIns: completedThisWeek, date: "2026-05-10"), 2)
        XCTAssertFalse(DomainLogic.canCompleteRoutine(on: "2026-05-10", routine: routine, checkIns: completedThisWeek))
        XCTAssertTrue(DomainLogic.canCompleteRoutine(on: "2026-05-11", routine: routine, checkIns: completedToday))
    }

    func testGoalStatsMatchWebRules() {
        let goal = Goal(
            id: "goal-1",
            title: "写完一本书",
            startDate: "2026-05-01",
            dueDate: "2026-05-31",
            status: .active,
            completedAt: nil,
            createdAt: "2026-05-01T08:00:00.000Z",
            updatedAt: "2026-05-01T08:00:00.000Z"
        )
        let routines = [
            Routine(id: "daily", goalId: goal.id, title: "写 500 字", frequency: .daily, createdAt: goal.createdAt, updatedAt: goal.updatedAt),
            Routine(id: "weekly", goalId: goal.id, title: "长篇复盘", frequency: .weeklyCount(timesPerWeek: 2), createdAt: goal.createdAt, updatedAt: goal.updatedAt)
        ]
        let checkIns = [
            CheckIn(id: "check-1", routineId: "daily", date: "2026-05-01", completed: true, recordedAt: "2026-05-01T21:00:00.000Z"),
            CheckIn(id: "check-2", routineId: "weekly", date: "2026-05-04", completed: true, recordedAt: "2026-05-04T21:00:00.000Z")
        ]

        let stats = DomainLogic.goalStats(goal: goal, routines: routines, tasks: [], checkIns: checkIns, today: "2026-05-10")

        XCTAssertEqual(stats.daysStarted, 10)
        XCTAssertEqual(stats.daysRemaining, 21)
        XCTAssertEqual(stats.completedCheckIns, 2)
        XCTAssertEqual(stats.dueCheckIns, 14)
        XCTAssertEqual(stats.completionRate, 14)
    }

    func testTodayProgressUsesVisibleReviewItems() {
        let goal = Goal(
            id: "goal-1",
            title: "稳定训练",
            startDate: "2026-05-11",
            dueDate: nil,
            status: .active,
            completedAt: nil,
            createdAt: "2026-05-11T08:00:00.000Z",
            updatedAt: "2026-05-11T08:00:00.000Z"
        )
        let routines = [
            Routine(id: "daily", goalId: goal.id, title: "每日阅读", frequency: .daily, createdAt: goal.createdAt, updatedAt: goal.updatedAt),
            Routine(id: "weekly", goalId: goal.id, title: "两次复盘", frequency: .weeklyCount(timesPerWeek: 2), createdAt: goal.createdAt, updatedAt: goal.updatedAt)
        ]
        let checkIns = [
            CheckIn(id: "check-1", routineId: "daily", date: "2026-05-11", completed: true, recordedAt: "2026-05-11T21:00:00.000Z"),
            CheckIn(id: "check-2", routineId: "weekly", date: "2026-05-11", completed: true, recordedAt: "2026-05-11T21:00:00.000Z")
        ]

        let progress = DomainLogic.todayProgress(goals: [goal], routines: routines, checkIns: checkIns, date: "2026-05-11")

        XCTAssertEqual(progress.completed, 2)
        XCTAssertEqual(progress.total, 2)
        XCTAssertEqual(progress.remaining, 0)
        XCTAssertEqual(progress.completionRate, 100)
    }

    func testTodayAgendaIncludesDueRoutinesAndActionableTasks() {
        let goal = Goal(
            id: "goal-1",
            title: "产品打磨",
            startDate: "2026-05-11",
            dueDate: nil,
            status: .active,
            completedAt: nil,
            createdAt: "2026-05-11T08:00:00.000Z",
            updatedAt: "2026-05-11T08:00:00.000Z"
        )
        let routine = Routine(id: "routine-1", goalId: goal.id, title: "复盘产品", frequency: .daily, createdAt: goal.createdAt, updatedAt: goal.updatedAt)
        let tasks = [
            OneOffTask(id: "task-open", goalId: goal.id, title: "无日期事项", completed: false, date: nil, createdAt: goal.createdAt, completedAt: nil),
            OneOffTask(id: "task-overdue", goalId: goal.id, title: "逾期事项", completed: false, date: "2026-05-12", createdAt: goal.createdAt, completedAt: nil),
            OneOffTask(id: "task-today", goalId: goal.id, title: "今日事项", completed: false, date: "2026-05-13", createdAt: goal.createdAt, completedAt: nil),
            OneOffTask(id: "task-future", goalId: goal.id, title: "未来事项", completed: false, date: "2026-05-14", createdAt: goal.createdAt, completedAt: nil),
            OneOffTask(id: "task-done", goalId: goal.id, title: "已完成事项", completed: true, date: "2026-05-13", createdAt: goal.createdAt, completedAt: "2026-05-13T09:00:00.000Z")
        ]

        let agenda = DomainLogic.todayAgenda(
            goals: [goal],
            routines: [routine],
            tasks: tasks,
            checkIns: [],
            date: "2026-05-13"
        )

        XCTAssertEqual(agenda.routineItems.map(\.routine.id), ["routine-1"])
        XCTAssertEqual(agenda.taskItems.map(\.task.id), ["task-open", "task-overdue", "task-today"])
        XCTAssertEqual(agenda.progress.total, 1)
    }

    func testVoyageSummaryCountsActiveCompletedTodayAndWeek() {
        let activeGoal = Goal(
            id: "active",
            title: "正在推进",
            startDate: "2026-05-01",
            dueDate: nil,
            status: .active,
            completedAt: nil,
            createdAt: "2026-05-01T08:00:00.000Z",
            updatedAt: "2026-05-01T08:00:00.000Z"
        )
        let completedGoal = Goal(
            id: "done",
            title: "已经点亮",
            startDate: "2026-05-01",
            dueDate: nil,
            status: .completed,
            completedAt: "2026-05-08T08:00:00.000Z",
            createdAt: "2026-05-01T08:00:00.000Z",
            updatedAt: "2026-05-08T08:00:00.000Z"
        )
        let routine = Routine(id: "daily", goalId: activeGoal.id, title: "每日阅读", frequency: .daily, createdAt: activeGoal.createdAt, updatedAt: activeGoal.updatedAt)
        let checkIns = [
            CheckIn(id: "check-1", routineId: routine.id, date: "2026-05-04", completed: true, recordedAt: "2026-05-04T21:00:00.000Z"),
            CheckIn(id: "check-2", routineId: routine.id, date: "2026-05-11", completed: true, recordedAt: "2026-05-11T21:00:00.000Z"),
            CheckIn(id: "check-3", routineId: routine.id, date: "2026-05-12", completed: true, recordedAt: "2026-05-12T21:00:00.000Z")
        ]

        let summary = DomainLogic.voyageSummary(
            goals: [activeGoal, completedGoal],
            routines: [routine],
            tasks: [],
            checkIns: checkIns,
            today: "2026-05-12"
        )

        XCTAssertEqual(summary.activeGoals, 1)
        XCTAssertEqual(summary.completedGoals, 1)
        XCTAssertEqual(summary.completedCheckIns, 3)
        XCTAssertEqual(summary.todayProgress.completed, 1)
        XCTAssertEqual(summary.todayProgress.total, 1)
        XCTAssertEqual(summary.weeklyCheckIns, 2)
    }

    func testRoutineMomentumReportsDailyStreakAndTotal() {
        let routine = Routine(
            id: "daily-momentum",
            goalId: "goal-1",
            title: "晨间阅读",
            frequency: .daily,
            createdAt: "2026-05-01T08:00:00.000Z",
            updatedAt: "2026-05-01T08:00:00.000Z"
        )
        let checkIns = [
            CheckIn(id: "check-1", routineId: routine.id, date: "2026-05-08", completed: true, recordedAt: "2026-05-08T21:00:00.000Z"),
            CheckIn(id: "check-2", routineId: routine.id, date: "2026-05-11", completed: true, recordedAt: "2026-05-11T21:00:00.000Z"),
            CheckIn(id: "check-3", routineId: routine.id, date: "2026-05-12", completed: true, recordedAt: "2026-05-12T21:00:00.000Z"),
            CheckIn(id: "check-4", routineId: routine.id, date: "2026-05-13", completed: true, recordedAt: "2026-05-13T21:00:00.000Z")
        ]

        let momentum = DomainLogic.routineMomentum(routine, checkIns: checkIns, today: "2026-05-13")

        XCTAssertEqual(momentum.completedTotal, 4)
        XCTAssertEqual(momentum.currentDailyStreak, 3)
        XCTAssertNil(momentum.weekTarget)
        XCTAssertEqual(momentum.weekCompleted, 0)
    }

    func testRoutineMomentumReportsWeeklyTargetProgress() {
        let routine = Routine(
            id: "weekly-momentum",
            goalId: "goal-1",
            title: "深度复盘",
            frequency: .weeklyCount(timesPerWeek: 3),
            createdAt: "2026-05-01T08:00:00.000Z",
            updatedAt: "2026-05-01T08:00:00.000Z"
        )
        let checkIns = [
            CheckIn(id: "check-1", routineId: routine.id, date: "2026-05-11", completed: true, recordedAt: "2026-05-11T21:00:00.000Z"),
            CheckIn(id: "check-2", routineId: routine.id, date: "2026-05-12", completed: true, recordedAt: "2026-05-12T21:00:00.000Z"),
            CheckIn(id: "check-3", routineId: routine.id, date: "2026-05-03", completed: true, recordedAt: "2026-05-03T21:00:00.000Z")
        ]

        let momentum = DomainLogic.routineMomentum(routine, checkIns: checkIns, today: "2026-05-13")

        XCTAssertEqual(momentum.completedTotal, 3)
        XCTAssertEqual(momentum.currentDailyStreak, 0)
        XCTAssertEqual(momentum.weekCompleted, 2)
        XCTAssertEqual(momentum.weekTarget, 3)
    }
}
