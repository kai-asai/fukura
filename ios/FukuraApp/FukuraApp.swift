import SwiftUI

@main
struct FukuraApp: App {
    @StateObject private var store = SnippetSharedStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear { store.load() }
        }
    }
}
