import SwiftUI
import SwiftData

@main
struct DiveIntoOceanApp: App {
    @AppStorage("appearance") private var appearance = 0
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .preferredColorScheme(appearance == 1 ? .light : appearance == 2 ? .dark : nil)
        }
        .modelContainer(for: [DiveLogEntry.self, Sighting.self, FavoriteItem.self])
    }
}
