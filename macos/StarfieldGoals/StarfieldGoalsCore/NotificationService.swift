import Foundation
import UserNotifications

public final class NotificationService {
    public static let reviewIdentifier = "starfield-goals.daily-review"

    public init() {}

    public func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    public func scheduleDailyReview(hour: Int = 21, minute: Int = 0) async {
        let content = UNMutableNotificationContent()
        content.title = "今晚复盘"
        content.body = "回到星图，点亮今天完成的轨道。"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.reviewIdentifier,
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    public func cancelDailyReview() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reviewIdentifier])
    }
}
