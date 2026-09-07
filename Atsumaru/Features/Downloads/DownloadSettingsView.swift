import SwiftUI
import Core

struct DownloadSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("dev.atsumaru.app.backgroundRefresh") private var backgroundRefreshEnabled = true
    @AppStorage("dev.atsumaru.app.autoDownloadAnyNetwork") private var autoDownloadAnyNetwork = false
    @AppStorage("dev.atsumaru.app.newChapterNotifications") private var newChapterNotifications = true
    @State private var storageUsed: Int64?

    var body: some View {
        Form {
            Section {
                Toggle("Background refresh", isOn: $backgroundRefreshEnabled)
                    .onChange(of: backgroundRefreshEnabled) { _, newValue in
                        if newValue {
                            if newChapterNotifications {
                                Task { await environment.backgroundScheduler.requestNotificationAuthorization() }
                            }
                            environment.backgroundScheduler.scheduleRefresh()
                        } else {
                            environment.backgroundScheduler.cancelRefresh()
                        }
                    }
                Toggle("Download over cellular", isOn: $autoDownloadAnyNetwork)
                    .onChange(of: autoDownloadAnyNetwork) { _, newValue in
                        Task { await environment.downloadManager.setAllowsCellularAccess(newValue) }
                    }
                Toggle("New chapter notifications", isOn: $newChapterNotifications)
                    .onChange(of: newChapterNotifications) { _, newValue in
                        if newValue {
                            Task { await environment.backgroundScheduler.requestNotificationAuthorization() }
                        }
                    }
            } header: {
                Text("Downloads")
            } footer: {
                Text("Background refresh periodically checks your library for newly published chapters. Timing is controlled by iOS. Cellular applies to all download traffic. Notifications require system permission.")
            }

            Section("Storage") {
                HStack {
                    Text("Downloads")
                    Spacer()
                    Text(storageUsed.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "…")
                        .foregroundStyle(.secondary)
                }
                if let date = BackgroundScheduler.lastRefreshDate() {
                    HStack {
                        Text("Last refresh")
                        Spacer()
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Download settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            storageUsed = await environment.downloadManager.storageUsed()
        }
    }
}
