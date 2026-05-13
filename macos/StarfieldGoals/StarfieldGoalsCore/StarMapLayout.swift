import CoreGraphics

public enum StarMapLayout {
    public static func screenFixedScale(cameraZoom: CGFloat) -> CGFloat {
        guard cameraZoom > 0 else {
            return 1
        }
        return 1 / cameraZoom
    }

    public static func starHitDiameter(focused: Bool) -> CGFloat {
        focused ? 82 : 54
    }

    public static func automaticZoom(goalCount: Int) -> CGFloat {
        guard goalCount > 0 else {
            return 1
        }
        return min(1.1, max(0.78, 1.08 - CGFloat(goalCount - 1) * 0.045))
    }

    public static func focusZoom(routineCount: Int, viewportWidth: CGFloat) -> CGFloat {
        let isCompact = viewportWidth < 760
        let base: CGFloat = isCompact ? 1.68 : 2.18
        let retreat = min(0.68, CGFloat(max(0, routineCount - 1)) * 0.105)
        return max(isCompact ? 1.12 : 1.32, base - retreat)
    }

    public static func anchoredPanAfterZoom(
        pointer: CGPoint,
        currentPan: CGSize,
        oldCameraZoom: CGFloat,
        newCameraZoom: CGFloat
    ) -> CGSize {
        guard oldCameraZoom > 0, newCameraZoom > 0 else {
            return currentPan
        }

        let contentX = (pointer.x - currentPan.width) / oldCameraZoom
        let contentY = (pointer.y - currentPan.height) / oldCameraZoom
        return CGSize(
            width: pointer.x - contentX * newCameraZoom,
            height: pointer.y - contentY * newCameraZoom
        )
    }

    public static func stableUnitInterval(_ value: String) -> Double {
        let hash = stableHash(value)
        return Double(hash % 1_000_000) / 1_000_000
    }

    public static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
