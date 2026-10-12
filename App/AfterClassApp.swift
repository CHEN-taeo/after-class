import SwiftUI

@main struct AfterClassApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .tint(Palette.ink)
                .preferredColorScheme(.light)
                .alert("稍等一下", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("知道了") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
