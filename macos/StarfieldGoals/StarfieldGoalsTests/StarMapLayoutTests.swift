import XCTest
@testable import StarfieldGoalsCore

final class StarMapLayoutTests: XCTestCase {
    func testScreenFixedScaleCounteractsCameraZoom() {
        XCTAssertEqual(StarMapLayout.screenFixedScale(cameraZoom: 2.0), 0.5, accuracy: 0.001)
        XCTAssertEqual(StarMapLayout.screenFixedScale(cameraZoom: 0), 1, accuracy: 0.001)
    }

    func testStarHitTargetStaysSmallInFocusedMode() {
        XCTAssertEqual(StarMapLayout.starHitDiameter(focused: false), 54)
        XCTAssertEqual(StarMapLayout.starHitDiameter(focused: true), 82)
    }

    func testStableUnitIntervalIsDeterministicForStarIdentity() {
        let first = StarMapLayout.stableUnitInterval("goal-alpha")
        let second = StarMapLayout.stableUnitInterval("goal-alpha")
        let other = StarMapLayout.stableUnitInterval("goal-beta")

        XCTAssertEqual(first, second, accuracy: 0.000001)
        XCTAssertNotEqual(first, other, accuracy: 0.000001)
        XCTAssertGreaterThanOrEqual(first, 0)
        XCTAssertLessThan(first, 1)
    }

    func testAutomaticZoomRetreatsAsConstellationGrows() {
        let oneGoal = StarMapLayout.automaticZoom(goalCount: 1)
        let manyGoals = StarMapLayout.automaticZoom(goalCount: 9)

        XCTAssertGreaterThan(oneGoal, manyGoals)
        XCTAssertEqual(StarMapLayout.automaticZoom(goalCount: 0), 1, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(manyGoals, 0.78)
    }

    func testFocusZoomRetreatsAsRoutineSystemGetsDenser() {
        let sparse = StarMapLayout.focusZoom(routineCount: 1, viewportWidth: 1100)
        let dense = StarMapLayout.focusZoom(routineCount: 8, viewportWidth: 1100)
        let mobile = StarMapLayout.focusZoom(routineCount: 8, viewportWidth: 620)

        XCTAssertGreaterThan(sparse, dense)
        XCTAssertGreaterThanOrEqual(dense, 1.32)
        XCTAssertLessThan(mobile, dense)
        XCTAssertGreaterThanOrEqual(mobile, 1.12)
    }

    func testAnchoredZoomKeepsPointerOverSameContentCoordinate() {
        let pointer = CGPoint(x: 420, y: 260)
        let pan = CGSize(width: -70, height: 34)
        let oldZoom: CGFloat = 1.05
        let newZoom: CGFloat = 1.38

        let nextPan = StarMapLayout.anchoredPanAfterZoom(
            pointer: pointer,
            currentPan: pan,
            oldCameraZoom: oldZoom,
            newCameraZoom: newZoom
        )

        let oldContentX = (pointer.x - pan.width) / oldZoom
        let oldContentY = (pointer.y - pan.height) / oldZoom
        let newContentX = (pointer.x - nextPan.width) / newZoom
        let newContentY = (pointer.y - nextPan.height) / newZoom

        XCTAssertEqual(oldContentX, newContentX, accuracy: 0.001)
        XCTAssertEqual(oldContentY, newContentY, accuracy: 0.001)
    }

    func testAnchoredZoomIgnoresInvalidZoomValues() {
        let pan = CGSize(width: 12, height: -8)

        XCTAssertEqual(
            StarMapLayout.anchoredPanAfterZoom(
                pointer: CGPoint(x: 100, y: 80),
                currentPan: pan,
                oldCameraZoom: 0,
                newCameraZoom: 1.2
            ),
            pan
        )
    }
}
