import XCTest
@testable import StarfieldGoalsCore

final class StorageAndBackupTests: XCTestCase {
    func testBackupRoundTripsWebCompatibleEnvelope() throws {
        let state = sampleState()
        let data = try BackupService().exportBackup(state: state, exportedAt: fixedDate())

        let imported = try BackupService().importBackup(data: data)

        XCTAssertEqual(imported, state)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"app\" : \"starfield-goals\"") || text.contains("\"app\":\"starfield-goals\""))
        XCTAssertTrue(text.contains("\"schemaVersion\" : 1") || text.contains("\"schemaVersion\":1"))
    }

    func testStorageRecoversFromLastGoodWhenPrimaryIsDamaged() throws {
        let directory = try temporaryDirectory()
        let storage = StorageService(directoryURL: directory)
        let state = sampleState()
        _ = try storage.save(state).get()
        try "{bad json".write(to: directory.appendingPathComponent("starfield-goals.json"), atomically: true, encoding: .utf8)

        let result = storage.load()

        XCTAssertEqual(result.status, .recovered)
        XCTAssertEqual(result.state.goals.first?.title, "长期目标")
    }

    func testStorageReturnsEmptySafeStateWhenNoFilesExist() throws {
        let storage = StorageService(directoryURL: try temporaryDirectory())

        let result = storage.load()

        XCTAssertEqual(result.status, .empty)
        XCTAssertEqual(result.state, .empty)
    }

    private func sampleState() -> AppState {
        AppState(
            version: 1,
            goals: [
                Goal(
                    id: "goal-1",
                    title: "长期目标",
                    startDate: "2026-05-11",
                    dueDate: nil,
                    status: .active,
                    completedAt: nil,
                    createdAt: "2026-05-11T10:00:00.000Z",
                    updatedAt: "2026-05-11T10:00:00.000Z"
                )
            ],
            routines: [
                Routine(
                    id: "routine-1",
                    goalId: "goal-1",
                    title: "每日点亮",
                    frequency: .daily,
                    createdAt: "2026-05-11T10:00:00.000Z",
                    updatedAt: "2026-05-11T10:00:00.000Z"
                )
            ],
            tasks: [],
            checkIns: [
                CheckIn(id: "check-1", routineId: "routine-1", date: "2026-05-11", completed: true, recordedAt: "2026-05-11T21:00:00.000Z")
            ],
            lastReminderDate: nil
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func fixedDate() -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: "2026-05-11T10:00:00.000Z")!
    }
}
