import SwiftUI
import Core

struct DownloadSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("dev.atsumaru.app.backgroundRefresh") private var backgroundRefreshEnabled = true
    @AppStorage("dev.atsumaru.app.autoDownloadAnyNetwork") private var autoDownloadAnyNetwork = false
    @AppStorage("dev.atsumaru.app.newChapterNotifications") private var newChapterNotifications = true

    var body: some View {
        Form {
            Section {
                Toggle("Background refresh", isOn: $backgroundRefreshEnabled)
                    .onChange(of: backgroundRefreshEnabled) { _, newValue in
                        if newValue {
                            Task { await environment.backgroundScheduler.requestNotificationAuthorization() }
                            environment.backgroundScheduler.scheduleRefresh()
                        }
                    }
                Toggle("Auto-download new chapters (any network)", isOn: $autoDownloadAnyNetwork)
                Toggle("New chapter notifications", isOn: $newChapterNotifications)
                    .onChange(of: newChapterNotifications) { _, newValue in
                        if newValue {
                            Task { await environment.backgroundScheduler.requestNotificationAuthorization() }
                        }
                    }
            } header: {
                Text("Downloads")
            } footer: {
                Text(backgroundRefreshEnabled
                     ? "New chapters for your library will be checked periodically."
                     : "Background refresh is off; new chapters will only be checked while you use the app.")
            }

            Section("Storage") {
                if let text = lastRefreshText {
                    HStack {
                        Text("Last refresh")
                        Spacer()
                        Text(text).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Storage cap")
                    Spacer()
                    Text("500 MB").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Download settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lastRefreshText: String? {
        guard let date = BackgroundScheduler.lastRefreshDate() else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}