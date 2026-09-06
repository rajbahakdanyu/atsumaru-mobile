import SwiftUI
import Core

struct FilterSheet: View {
    @Bindable var viewModel: BrowseViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tagSearch = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let filters = viewModel.filters {
                        sortSection
                        filterSection("Genres", items: filters.genres, selection: $viewModel.query.genres)
                        typeSection(items: filters.types)
                        statusSection(items: filters.statuses)
                        mediumSection
                        tagSection(items: filters.tags)
                        minChaptersSection
                    } else if viewModel.filtersLoadFailed {
                        ContentUnavailableView {
                            Label("Couldn't load filters", systemImage: "exclamationmark.triangle")
                        } actions: {
                            Button("Retry") { Task { await viewModel.loadFilters() } }
                        }
                        .padding(.top, 60)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.clear)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) { viewModel.clearFilters() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        if viewModel.hasActiveFilters {
                            viewModel.prepareFilteredReload()
                        }
                        dismiss()
                    }.bold()
                }
            }
            .task { await viewModel.loadFilters() }
        }
    }

    private var sortSection: some View {
        section(title: "Sort") {
            menuRow(label: viewModel.sort.label) {
                ForEach(BrowseSort.allCases) { s in
                    Button {
                        viewModel.sort = s
                    } label: {
                        if s == viewModel.sort {
                            Label(s.label, systemImage: "checkmark")
                        } else {
                            Text(s.label)
                        }
                    }
                }
            }
        }
    }

    private func menuRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            content()
        }
    }

    private func filterSection(_ title: String, items: [NamedFilter], selection: Binding<[String]>) -> some View {
        section(title: title) {
            flowChips(items: items, selection: selection)
        }
    }

    private func typeSection(items: [NamedFilter]) -> some View {
        filterSection("Types", items: items, selection: $viewModel.query.types)
    }

    private func statusSection(items: [NamedFilter]) -> some View {
        filterSection("Statuses", items: items, selection: $viewModel.query.statuses)
    }

    private var mediumSection: some View {
        section(title: "Medium") {
            FlowLayout(spacing: 8) {
                chip("Comic", id: "Comic", selection: $viewModel.query.mediums)
                chip("Novel", id: "Novel", selection: $viewModel.query.mediums)
            }
        }
    }

    private func tagSection(items: [NamedFilter]) -> some View {
        section(title: "Tags") {
            let selectedTags = items.filter { viewModel.query.tags.contains($0.id) }
            if !selectedTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedTags) { f in
                        selectedTagChip(f)
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tags", text: $tagSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !tagSearch.isEmpty {
                    Button {
                        tagSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            let filtered = tagSearch.isEmpty
                ? []
                : items.filter { $0.name.localizedCaseInsensitiveContains(tagSearch) }
            if tagSearch.isEmpty {
                Text("\(items.count) tags — search to narrow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else if filtered.isEmpty {
                Text("No matching tags.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filtered) { f in
                            tagRow(f)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .contentMargins(.vertical, 4, for: .scrollContent)
            }
        }
    }

    private func selectedTagChip(_ f: NamedFilter) -> some View {
        Button {
            viewModel.query.tags.removeAll { $0 == f.id }
        } label: {
            HStack(spacing: 4) {
                Text(f.name)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(Color.accentColor)
            .background(Color.accentColor.opacity(0.18), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func tagRow(_ f: NamedFilter) -> some View {
        let selected = viewModel.query.tags.contains(f.id)
        return Button {
            if selected {
                viewModel.query.tags.removeAll { $0 == f.id }
            } else {
                viewModel.query.tags.append(f.id)
            }
        } label: {
            HStack {
                Text(f.name)
                    .font(.subheadline)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                Spacer()
                if let group = f.group {
                    Text(group).font(.caption2).foregroundStyle(.secondary)
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var minChaptersSection: some View {
        section(title: "Minimum chapters") {
            menuRow(label: minChaptersLabel) {
                Button {
                    viewModel.query.minChapters = nil
                } label: {
                    if viewModel.query.minChapters == nil {
                        Label("Any", systemImage: "checkmark")
                    } else {
                        Text("Any")
                    }
                }
                ForEach([1, 5, 10, 25, 50, 100, 200, 500], id: \.self) { n in
                    Button {
                        viewModel.query.minChapters = n
                    } label: {
                        if viewModel.query.minChapters == n {
                            Label("\(n)+", systemImage: "checkmark")
                        } else {
                            Text("\(n)+")
                        }
                    }
                }
            }
        }
    }

    private var minChaptersLabel: String {
        if let n = viewModel.query.minChapters { return "\(n)+" }
        return "Any"
    }

    private func flowChips(items: [NamedFilter], selection: Binding<[String]>) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { f in
                chip(f.name, id: f.id, selection: selection)
            }
        }
    }

    private func chip(_ label: String, id: String, selection: Binding<[String]>) -> some View {
        let selected = selection.wrappedValue.contains(id)
        return Button {
            if selected {
                selection.wrappedValue.removeAll { $0 == id }
            } else {
                selection.wrappedValue.append(id)
            }
        } label: {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .background(selected ? Color.accentColor.opacity(0.18) : Color.clear, in: Capsule())
                .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

