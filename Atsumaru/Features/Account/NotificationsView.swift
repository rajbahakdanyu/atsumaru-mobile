import SwiftUI
import Core

struct NotificationsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: NotificationsViewModel?

    var body: some View {
        List {
            if let items = viewModel?.notifications, !items.isEmpty {
                ForEach(items) { item in
                    NotificationRow(item: item)
                }
            } else if let error = viewModel?.error {
                ErrorStateView(error: error) { Task { await viewModel?.load() } }
                    .listRowBackground(Color.clear)
            } else if viewModel?.isLoading == false {
                EmptyStateView(message: "You're all caught up.")
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            if let unread = viewModel?.unreadCount, unread > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel?.markAllRead() }
                    } label: {
                        Label("Mark all read", systemImage: "checkmark.circle")
                    }
                    .disabled(viewModel?.isMarking == true)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = NotificationsViewModel(userRepository: environment.userRepository)
            }
            await viewModel?.load()
        }
    }
}

@ViewBuilder
private func NotificationRow(item: NotificationItem) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline) {
            Text(item.title ?? "Notification")
                .font(.body.bold())
            Spacer()
            if let unread = item.read, unread == false {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }
            if let createdAt = item.createdAt {
                Text(NotificationsView.dateString(for: createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        if let body = item.body, !body.isEmpty {
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding(.vertical, 4)
}

@Observable @MainActor
final class NotificationsViewModel {
    var notifications: [NotificationItem] = []
    var unreadCount: Int = 0
    var isLoading = false
    var isMarking = false
    var error: ApiError?

    private let userRepository: any UserRepository

    init(userRepository: any UserRepository) {
        self.userRepository = userRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let listTask = userRepository.notifications()
        async let countTask = userRepository.notificationCount()

        do {
            notifications = try await listTask
            error = nil
        } catch {
            self.error = (error as? ApiError) ?? .decoding
        }
        unreadCount = (try? await countTask) ?? 0
    }

    func markAllRead() async {
        isMarking = true
        defer { isMarking = false }
        do {
            try await userRepository.markAllNotificationsRead()
            await load()
        } catch {
            // best-effort; leave the list as-is on failure
        }
    }
}

extension NotificationsView {
    static func dateString(for epochMs: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}