import SwiftUI

@main
struct AtsumaruApp: App {
    @State private var environment = AppEnvironment()
    @AppStorage("appTheme") private var appTheme: AppTheme = .slate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .tint(appTheme.accent)
                .task { await environment.bootstrap() }
        }
    }
}