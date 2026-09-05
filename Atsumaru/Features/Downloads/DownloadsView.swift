import SwiftUI
import Core

struct DownloadsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: DownloadsViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Downloads")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            DownloadSettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .task {
            if viewModel == nil {
                viewModel = DownloadsViewModel(
                    downloadManager: environment.downloadManager,
                    backgroundScheduler: environment.backgroundScheduler
                )
            }
            await viewModel?.load()
        }
        .onDisappear {
            viewModel?.stopEventStream()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            @Bindable var vm = viewModel
            VStack(spacing: 0) {
                if let storageText = vm.storageText {
                    HStack {
                        Label(storageText, systemImage: "internaldrive")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await vm.deleteAll() }
                        } label: {
                            Text("Clear All")
                                .font(.footnote)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                List {
                    if vm.rows.isEmpty {
                        ContentUnavailableView(
                            "No downloads",
                            systemImage: "arrow.down.circle",
                            description: Text("Bookmark chapters from a manga page to keep them offline.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(vm.rows) { row in
                            downloadRow(row)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.delete(row.chapterId) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .listStyle(.plain)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func downloadRow(_ row: DownloadsViewModel.DownloadRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.mangaTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text(row.kind.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassCapsule()
            }
            Text(row.chapterTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 8) {
                progressCapsule(for: row)
                Text(row.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let size = row.sizeText {
                    Text(size)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func progressCapsule(for row: DownloadsViewModel.DownloadRow) -> some View {
        switch row.state {
        case .queued:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .downloading(let fraction):
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .frame(maxWidth: 100)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}
