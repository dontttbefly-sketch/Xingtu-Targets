import StarfieldGoalsCore
import SwiftUI

extension Notification.Name {
    static let starfieldCreateGoal = Notification.Name("starfieldCreateGoal")
    static let starfieldQuickCapture = Notification.Name("starfieldQuickCapture")
    static let starfieldOpenToday = Notification.Name("starfieldOpenToday")
    static let starfieldOpenReview = Notification.Name("starfieldOpenReview")
    static let starfieldOpenDataVault = Notification.Name("starfieldOpenDataVault")
    static let starfieldOpenVoyageLog = Notification.Name("starfieldOpenVoyageLog")
    static let starfieldReturnToMap = Notification.Name("starfieldReturnToMap")
}

@main
struct StarfieldGoalsApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1040, minHeight: 720)
                .task {
                    let notifications = NotificationService()
                    if await notifications.requestAuthorization() {
                        await notifications.scheduleDailyReview()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("创造恒星") {
                    NotificationCenter.default.post(name: .starfieldCreateGoal, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("快速捕获") {
                    NotificationCenter.default.post(name: .starfieldQuickCapture, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandMenu("星图") {
                Button("今日轨道") {
                    NotificationCenter.default.post(name: .starfieldOpenToday, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("今晚复盘") {
                    NotificationCenter.default.post(name: .starfieldOpenReview, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("航行日志") {
                    NotificationCenter.default.post(name: .starfieldOpenVoyageLog, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("数据舱") {
                    NotificationCenter.default.post(name: .starfieldOpenDataVault, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Divider()

                Button("返回星图") {
                    NotificationCenter.default.post(name: .starfieldReturnToMap, object: nil)
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}
