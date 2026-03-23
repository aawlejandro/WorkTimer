import SwiftUI
import SwiftData

@main
struct WorkTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: WorkSession.self)
    }
}
