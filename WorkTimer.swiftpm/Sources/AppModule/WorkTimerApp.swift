import SwiftUI
import SwiftData

@main
struct WorkTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // SwiftData container — schema is inferred from WorkSession model.
        .modelContainer(for: WorkSession.self)
    }
}
