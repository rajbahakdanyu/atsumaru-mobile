import SwiftUI
import Kingfisher
import Core

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: LibraryViewModel?
    @State private var showingNewList = false

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 108), spacing: 12)]

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
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for viewModel: LibraryViewModel) -> some View {
        @Bindable var viewModel = viewModel
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
                    } else {
                        ContinueReadingView(items: viewModel.continueReading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                }

            case .bookmarks:
                ScrollView {
                    if viewModel.bookmarks.isEmpty && !viewModel.isLoading {
                        EmptyStateView(message: "No bookmarks")
                            .padding(.top, 20)
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

            case .history:
                ScrollView {
                    if viewModel.history.isEmpty && !viewModel.isLoading {
                        EmptyStateView(message: "No history")
                            .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.history) { entry in
                                NavigationLink(value: entry.mangaId ?? entry.id) {
                                    historyRow(entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }

            case .lists:
                List {
                    Section {
                        ForEach(viewModel.lists) { list in
                            listRow(list)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteList(list) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    if viewModel.lists.isEmpty && !viewModel.isLoading {
                        Section {
                            EmptyStateView(message: "No lists yet")
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: String.self) { id in
            MangaDetailView(mangaId: id)
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
    }

    @ViewBuilder
    private func bookmarkCell(_ bookmark: Bookmark) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage(bookmark.image.flatMap(ImageURLBuilder.poster))
                .resizable()
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
            KFImage(entry.image.flatMap(ImageURLBuilder.poster))
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title ?? "Untitled")
                    .font(.subheadline)
                    .lineLimit(1)
                if let chapter = entry.chapterTitle {
                    Text(chapter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let readAt = entry.readAt {
                    Text(readAt)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCapsule()
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
            if let count = list.itemCount {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
