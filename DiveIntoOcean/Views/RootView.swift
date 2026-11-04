import SwiftUI

struct StartLogKey: EnvironmentKey { static let defaultValue: @MainActor @Sendable (String?) -> Void = { _ in } }
extension EnvironmentValues { var startLog: @MainActor @Sendable (String?) -> Void { get { self[StartLogKey.self] } set { self[StartLogKey.self] = newValue } } }

struct RootView: View {
    @State private var tab = 0
    @State private var showCreate = false
    @State private var createSite: String? = nil
    var body: some View {
        TabView(selection: $tab) {
            Tab("探索", systemImage: tab == 0 ? "safari.fill" : "safari", value: 0) {
                ExploreView()
            }
            Tab("日志", systemImage: tab == 1 ? "book.closed.fill" : "book.closed", value: 1) {
                LogListView()
            }
            Tab("我的", systemImage: tab == 2 ? "person.crop.circle.fill" : "person.crop.circle", value: 2) {
                MeView(goExplore: { tab = 0 })
            }
        }
        .environment(\.startLog, { site in createSite = site; showCreate = true })
        .sheet(isPresented: $showCreate) { LogEditorView(presetSite: createSite, onSaved: { _ in }) }
    }
}
