import SwiftData
import SwiftUI

@main
struct StarfieldGoalsApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var notificationRouter = NotificationRouter.shared

    init() {
        NotificationService.configure()
        let schema = Schema([
            GoalRecord.self,
            RoutineRecord.self,
            OneOffTaskRecord.self,
            CheckInRecord.self,
            AppMetaRecord.self
        ])

        #if targetEnvironment(simulator)
        let configuration = ModelConfiguration(
            "StarfieldGoals",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        #else
        let configuration = ModelConfiguration(
            "StarfieldGoals",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.bottom.starfieldgoals")
        )
        #endif

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let localConfiguration = ModelConfiguration(
                "StarfieldGoalsLocal",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Unable to create StarfieldGoals model container: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environmentObject(notificationRouter)
        }
    }
}
