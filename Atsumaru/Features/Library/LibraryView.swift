import SwiftUI
import Kingfisher
import Core

/// Direct-into-reader resume target for a continue-reading item
/// (website parity: /read/{mangaId}/{chapterId} or /novel/{mangaId}/{chapterId}).
struct ReaderResume: Hashable {
    let mangaId: String
    let chapter: Chapter
    let isNovel: Bool
}

/// Push target for opening one user list's detail screen.
struct ListOpen: Hashable {
    let listId: String
}

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.displayScale) private var displayScale
    @State private var viewModel: LibraryViewModel?
    @State private var showingNewList = false
    @State private var showAuth = false
    @State private var listToDelete: UserList?

    private let columns = PosterGrid.columns

    var body: some View {
        NavigationStack {
            if let viewModel {
                content(for: viewModel)
            } else {
                LoadingSkeletonView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = LibraryViewModel(repository: environment.libraryRepository)
            }
            if environment.currentUser != nil {
                await viewModel?.load()
            }
        }
        .onChange(of: environment.currentUser) { _, user in
            if user != nil {
                Task { await viewModel?.load(force: true) }
            }
        }
        .authSheet(isPresented: $showAuth, environment: environment)
    }

    @ViewBuilder
    private func content(for viewModel: LibraryViewModel) -> some View {
        @Bindable var viewModel = viewModel
        Group {
            if environment.currentUser == nil {
                signedOutContent
            } else if let error = viewModel.error, !viewModel.isLoading, viewModel.hasNothing {
                ErrorStateView(error: error) { Task { await viewModel.load(force: true) } }
            } else {
                VStack(spacing: 0) {
                    Picker("Library", selection: $viewModel.segment) {
                        ForEach(LibraryViewModel.Segment.allCases) { segment in
                            Text(segment.label).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    switch viewModel.segment {
                    case .continueReading:
                        ScrollView {
                            if viewModel.isLoading && viewModel.continueReading.isEmpty {
                                LoadingSkeletonView()
                                    .padding(.top, 20)
                            } else if viewModel.continueReading.isEmpty, let error = viewModel.error {
                                ErrorStateView(error: error) { Task { await viewModel.load(force: true) } }
                                    .padding(.top, 20)
                            } else {
                                ContinueReadingView(items: viewModel.continueReading)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 24)
                            }
                        }
                        .refreshable { await viewModel.load(force: true) }

                    case .bookmarks:
                        ScrollView {
                            if viewModel.bookmarks.isEmpty && !viewModel.isLoading {
                                if let error = viewModel.error {
                                    ErrorStateView(error: error) { Task { await viewModel.load(force: true) } }
                                        .padding(.top, 20)
                                } else {
                                    ContentUnavailableView("No bookmarks", systemImage: "bookmark")
                                        .padding(.top, 20)
                                }
                            } else {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.bookmarks) { bookmark in
                                        NavigationLink(value: bookmark.id) {
                                            bookmarkCell(bookmark)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                            }
                        }
                        .refreshable { await viewModel.load(force: true) }

                    case .history:
                        ScrollView {
                            if viewModel.history.isEmpty && !viewModel.isLoading {
                                if let error = viewModel.error {
                                    ErrorStateView(error: error) { Task { await viewModel.load(force: true) } }
                                        .padding(.top, 20)
                                } else {
                                    ContentUnavailableView("No history", systemImage: "clock.arrow.circlepath")
                                        .padding(.top, 20)
                                }
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(viewModel.history) { entry in
                                        NavigationLink(value: entry.id) {
                                            historyRow(entry)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                            }
                        }
                        .refreshable { await viewModel.load(force: true) }

                    case .lists:
                        List {
                            Section {
                                ForEach(viewModel.lists) { list in
                                    NavigationLink(value: ListOpen(listId: list.id)) {
                                        listRow(list)
                                    }
                                    .contextMenu {
                                        Button {
                                            Task { await viewModel.setPinned(list, !list.pinned) }
                                        } label: {
                                            Label(list.pinned ? "Unpin" : "Pin",
                                                  systemImage: list.pinned ? "pin.slash" : "pin")
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            listToDelete = list
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            if viewModel.lists.isEmpty && !viewModel.isLoading {
                                Section {
                                    if let error = viewModel.error {
                                        ErrorStateView(error: error) { Task { await viewModel.load(force: true) } }
                                    } else {
                                        ContentUnavailableView("No lists yet", systemImage: "list.bullet")
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { await viewModel.load(force: true) }
                    }
                }
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: String.self) { id in
            MangaDetailView(mangaId: id)
        }
        .navigationDestination(for: ListOpen.self) { open in
            ListDetailView(listId: open.listId)
        }
        .navigationDestination(for: ReaderResume.self) { resume in
            if resume.isNovel {
                NovelReaderView(mangaId: resume.mangaId, chapter: resume.chapter)
            } else {
                MangaReaderView(mangaId: resume.mangaId, chapter: resume.chapter)
            }
        }
        .toolbar {
            if viewModel.segment == .lists {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("New List", isPresented: $showingNewList) {
            TextField("List name", text: $viewModel.newListName)
            Button("Create") {
                Task { await viewModel.createList() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.newListName = ""
            }
        }
        .confirmationDialog(
            "Delete list?",
            isPresented: Binding(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let list = listToDelete else { return }
                listToDelete = nil
                Task { await viewModel.deleteList(list) }
            }
            Button("Cancel", role: .cancel) {
                listToDelete = nil
            }
        } message: {
            Text("This can't be undone.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.actionError != nil },
                set: { if !$0 { viewModel.actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.actionError = nil }
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    @ViewBuilder
    private var signedOutContent: some View {
        SignedOutView(message: "Sign in to view your library and reading progress.") {
            showAuth = true
        }
    }

    @ViewBuilder
    private func bookmarkCell(_ bookmark: Bookmark) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage.poster(bookmark.image.flatMap(ImageURLBuilder.poster), displayScale: displayScale)
                .scaledToFill()
                .frame(width: 108, height: 154)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(bookmark.title)
                .font(.caption)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func historyRow(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 12) {
            KFImage.poster(entry.image.flatMap(ImageURLBuilder.poster), displayScale: displayScale)
                .scaledToFill()
                .frame(width: 48, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title ?? "Untitled")
                    .font(.subheadline)
                    .lineLimit(1)
                if let chapter = chapterSubtitle(for: entry) {
                    Text(chapter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let date = entry.readAtDate {
                    Text(date.relativeLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func chapterSubtitle(for entry: HistoryEntry) -> String? {
        if let title = entry.chapterTitle, !title.isEmpty { return title }
        if let number = entry.chapterNumber {
            let value = number.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(number))
                : String(number)
            return "Chapter \(value)"
        }
        return nil
    }

    @ViewBuilder
    private func listRow(_ list: UserList) -> some View {
        HStack {
            Image(systemName: "list.bullet")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name ?? "Untitled list")
                    .lineLimit(1)
                if let desc = list.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if list.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
    }
}
