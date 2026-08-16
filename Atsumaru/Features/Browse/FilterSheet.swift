import SwiftUI
import Core

struct FilterSheet: View {
    @Bindable var viewModel: BrowseViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tagSearch = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) { viewModel.clearFilters() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { dismiss() }.bold()
                }
            }
            .task { await viewModel.loadFilters() }
        }
    }

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sort").font(.headline).padding(.leading, 4)
            Picker("Sort by", selection: $viewModel.sort) {
                ForEach(BrowseSort.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .glassCapsule()
        }
    }

    private func filterSection(_ title: String, items: [NamedFilter], selection: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.leading, 4)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Medium").font(.headline).padding(.leading, 4)
            HStack(spacing: 8) {
                mediumChip("Comic", "Comic")
                mediumChip("Novel", "Novel")
            }
        }
    }

    private func mediumChip(_ label: String, _ value: String) -> some View {
        let selected = viewModel.query.mediums.contains(value)
        return Button {
            if selected {
                viewModel.query.mediums.removeAll { $0 == value }
            } else {
                viewModel.query.mediums.append(value)
            }
        } label: {
            Text(label)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .glassCapsule()
        }
        .buttonStyle(.plain)
    }

    private func tagSection(items: [NamedFilter]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.headline).padding(.leading, 4)
            TextField("Search tags", text: $tagSearch)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            let filtered = tagSearch.isEmpty
                ? []
                : items.filter { $0.name.localizedCaseInsensitiveContains(tagSearch) }
            if tagSearch.isEmpty {
                Text("\(items.count) tags — search to narrow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                if filtered.isEmpty {
                    Text("No matching tags.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(filtered) { f in
                                tagRow(f)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
        }
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
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                Spacer()
                if let group = f.group {
                    Text(group).font(.caption2).foregroundStyle(.secondary)
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var minChaptersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Minimum chapters").font(.headline).padding(.leading, 4)
            Picker("Min chapters", selection: Binding(
                get: { viewModel.query.minChapters ?? 0 },
                set: { viewModel.query.minChapters = $0 == 0 ? nil : $0 }
            )) {
                Text("Any").tag(0)
                ForEach([1, 5, 10, 25, 50, 100, 200, 500], id: \.self) { n in
                    Text("\(n)+").tag(n)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .glassCapsule()
        }
    }

    private func flowChips(items: [NamedFilter], selection: Binding<[String]>) -> some View {
        FilterFlowLayout(spacing: 8) {
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
                .font(.footnote)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .glassCapsule()
        }
        .buttonStyle(.plain)
    }
}

struct FilterFlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
