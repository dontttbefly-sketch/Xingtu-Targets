import CloudKit
import Foundation
import UserNotifications

enum ICloudAccountState: Equatable {
    case checking
    case available
    case localOnly(String)
    case unavailable(String)

    var message: String {
        switch self {
        case .checking:
            return "正在检查 iCloud 同步状态..."
        case .available:
            return "iCloud 已连接，数据会随 Apple ID 同步。"
        case .localOnly(let reason):
            return reason
        case .unavailable(let reason):
            return "本机可用，登录 iCloud 后同步。\(reason)"
        }
    }
}

@MainActor
final class ICloudStatusService: ObservableObject {
    @Published private(set) var state: ICloudAccountState = .checking

    func refresh() async {
        #if targetEnvironment(simulator)
        state = .localOnly("模拟器使用本地数据；真机/TestFlight 签名后会启用 iCloud 同步。")
        return
        #else
        do {
            let status = try await CKContainer.default().accountStatus()
            switch status {
            case .available:
                state = .available
            case .noAccount:
                state = .unavailable("当前设备没有登录 iCloud。")
            case .restricted:
                state = .unavailable("iCloud 账号受系统限制。")
            case .couldNotDetermine:
                state = .unavailable("暂时无法确认 iCloud 状态。")
            case .temporarilyUnavailable:
                state = .unavailable("iCloud 暂时不可用。")
            @unknown default:
                state = .unavailable("遇到未知 iCloud 状态。")
            }
        } catch {
            state = .unavailable(error.localizedDescription)
        }
        #endif
    }
}

final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    nonisolated(unsafe) static let shared = NotificationRouter()

    @Published var reviewOpenRequest = 0

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.notification.request.identifier == NotificationService.eveningReviewIdentifier {
            await MainActor.run {
                NotificationRouter.shared.reviewOpenRequest += 1
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

enum NotificationService {
    static let eveningReviewIdentifier = "starfield-evening-review"

    static func configure(router: NotificationRouter = .shared) {
        UNUserNotificationCenter.current().delegate = router
    }

    static func requestAuthorizationAndScheduleDailyReview() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else {
            return
        }
        try await scheduleDailyReview()
    }

    static func scheduleDailyReview(hour: Int = 21, minute: Int = 0) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [eveningReviewIdentifier])

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "今晚复盘"
        content.body = "检查今天的行星轨道，把完成的 routine 点亮。"
        content.sound = .default
        content.threadIdentifier = "starfield-review"

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: eveningReviewIdentifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }
}
