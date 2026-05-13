import XCTest
@testable import StarfieldGoalsCore

@MainActor
final class AppStoreTests: XCTestCase {
    func testCreatesGoalRoutineAndTogglesTodayCompletion() {
        let store = AppStore(initialState: .empty, autosaves: false)

        let goal = store.addGoal(title: "完成原生星图", startDate: "2026-05-11", dueDate: nil)
        let routine = store.addRoutine(goalId: goal.id, title: "点亮 SwiftUI", frequency: .daily)
        store.toggleCheckIn(routineId: routine.id, date: "2026-05-11", completed: true)

        let stats = store.stats(for: goal.id, today: "2026-05-11")
        XCTAssertEqual(store.state.goals.first?.title, "完成原生星图")
        XCTAssertEqual(store.state.routines.first?.title, "点亮 SwiftUI")
        XCTAssertEqual(stats?.completedCheckIns, 1)
        XCTAssertEqual(stats?.completionRate, 100)
    }

    func testDeletingGoalCascadesRoutineTasksAndCheckIns() {
        let store = AppStore(initialState: .empty, autosaves: false)
        let goal = store.addGoal(title: "删除测试", startDate: "2026-05-11", dueDate: nil)
        let routine = store.addRoutine(goalId: goal.id, title: "删除轨道", frequency: .daily)
        let task = store.addTask(goalId: goal.id, title: "删除事项", date: nil)
        store.toggleCheckIn(routineId: routine.id, date: "2026-05-11", completed: true)

        store.deleteGoal(goal.id)

        XCTAssertTrue(store.state.goals.isEmpty)
        XCTAssertTrue(store.state.routines.isEmpty)
        XCTAssertFalse(store.state.tasks.contains { $0.id == task.id })
        XCTAssertTrue(store.state.checkIns.isEmpty)
    }

    func testUpdatesOneOffTaskTitleAndDate() {
        let store = AppStore(initialState: .empty, autosaves: false)
        let goal = store.addGoal(title: "事项编辑测试", startDate: "2026-05-11", dueDate: nil)
        var task = store.addTask(goalId: goal.id, title: "旧事项", date: nil)

        task.title = "更新后的事项"
        task.date = "2026-05-13"
        store.updateTask(task)

        XCTAssertEqual(store.state.tasks.first?.title, "更新后的事项")
        XCTAssertEqual(store.state.tasks.first?.date, "2026-05-13")
    }
}
