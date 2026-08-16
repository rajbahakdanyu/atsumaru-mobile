import SwiftUI
import Core

struct FilterSheet: View {
    @Bindable var viewModel: BrowseViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let filters = viewModel.filters {
                        filterSection("Genres", items: filters.genres, selection: $viewModel.query.genres)
                        filterSection("Tags", items: filters.tags, selection: $viewModel.query.tags)
                        filterSection("Types", items: filters.types, selection: $viewModel.query.types)
                        filterSection("Statuses", items: filters.statuses, selection: $viewModel.query.statuses)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 80)
                    }
                    sortSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) { clear() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { dismiss() }.bold()
                }
            }
        }
    }

    private func filterSection(_ title: String, items: [NamedFilter], selection: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.leading, 4)
            VStack(spacing: 6) {
                ForEach(items) { f in toggleRow(f, selection: selection) }
            }
        }
    }

    private func toggleRow(_ f: NamedFilter, selection: Binding<[String]>) -> some View {
        let selected = selection.wrappedValue.contains(f.id)
        return Button {
            if selected {
                selection.wrappedValue.removeAll { $0 == f.id }
            } else {
                selection.wrappedValue.append(f.id)
            }
        } label: {
            HStack {
                Text(f.name)
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .glassCapsule()
        }
        .buttonStyle(.plain)
    }

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sort")
                .font(.headline)
                .padding(.leading, 4)
            Picker("Sort by", selection: $viewModel.query.sortBy) {
                Text("Relevance").tag("")
                Text("Top rated").tag("mbRating:desc")
                Text("Most chapters").tag("chapterCount:desc")
                Text("Recently updated").tag("updatedAt:desc")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .glassCapsule()
        }
    }

    private func clear() {
        viewModel.query.genres = []
        viewModel.query.tags = []
        viewModel.query.types = []
        viewModel.query.statuses = []
        viewModel.query.sortBy = ""
    }
}