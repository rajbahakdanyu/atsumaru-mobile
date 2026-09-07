import SwiftUI

@main
struct AtsumaruApp: App {
    @State private var environment = AppEnvironment()
    @AppStorage("appTheme") private var appTheme: AppTheme = .slate
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    var body: some Scene {
        WindowGroup {
            Group {
                if isRunningTests {
                    Color.clear
                } else {
                    RootView()
                }
            }
                .environment(environment)
                .tint(appTheme.accent)
                .task {
                    if !isRunningTests { await environment.bootstrap() }
                }
        }
    }
}