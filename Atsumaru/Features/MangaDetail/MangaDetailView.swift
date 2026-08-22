import SwiftUI
import Core
import Kingfisher

struct MangaDetailView: View {
    let mangaId: String
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: MangaDetailViewModel?
    @State private var detailsExpanded = false

    var body: some View {
        Group {
            if let manga = viewModel?.manga {
                content(for: manga)
            } else if viewModel?.loadFailed == true {
                ContentUnavailableView {
                    Label("Couldn't load manga", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Something went wrong. Please try again.")
                } actions: {
                    Button("Retry") {
                        Task { await viewModel?.load() }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel?.manga?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Chapter.self) { chapter in
            if viewModel?.manga?.medium == "Novel" {
                NovelReaderView(mangaId: mangaId, chapter: chapter)
            } else {
                MangaReaderView(mangaId: mangaId, chapter: chapter)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = MangaDetailViewModel(
                    mangaId: mangaId,
                    mangaRepository: environment.mangaRepository
                )
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for manga: MangaPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(manga)
                detailsSection(manga)
                continueReadingButton(for: manga)
                chapterSection(manga)
            }
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func header(_ manga: MangaPage) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let path = manga.poster?.image, let url = ImageURLBuilder.poster(path) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Rectangle()
                    .fill(.thinMaterial)
                    .frame(width: 110, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                if let status = manga.status, !status.isEmpty {
                    labeledRow("Status", status)
                }
                if let rating = manga.avgRating {
                    labeledRow("Rating", rating.formatted(.number.precision(.fractionLength(1))))
                }
                let authors = manga.authors.filter { $0.type?.lowercased() != "artist" }
                if !authors.isEmpty {
                    labeledRow("Author", authors.map(\.name).joined(separator: ", "))
                }
                let artists = manga.authors.filter { $0.type?.lowercased() == "artist" }
                if !artists.isEmpty {
                    labeledRow("Artist", artists.map(\.name).joined(separator: ", "))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func detailsSection(_ manga: MangaPage) -> some View {
        let genres = manga.genres.map(\.name)
        let tags = manga.tags.map(\.name)
        let hasSynopsis = !(manga.synopsis?.isEmpty ?? true)
        if hasSynopsis || !genres.isEmpty || !tags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.snappy) { detailsExpanded.toggle() }
                } label: {
                    HStack {
                        Text("Details")
                            .font(.headline)
                        Spacer()
                        Image(systemName: detailsExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)

                if hasSynopsis {
                    Text(manga.synopsis ?? "")
                        .font(.body)
                        .lineLimit(detailsExpanded ? nil : 2)
                }

                if !genres.isEmpty {
                    if detailsExpanded {
                        FlowLayout(spacing: 8) {
                            ForEach(genres, id: \.self) { chip($0) }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(genres, id: \.self) { chip($0) }
                            }
                        }
                    }
                }

                if detailsExpanded, !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { chip($0) }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func continueReadingButton(for manga: MangaPage) -> some View {
        if let chapter = startReadingChapter(in: manga) {
            NavigationLink(value: chapter) {
                Label("Continue Reading", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 16)
        }
    }

    private func startReadingChapter(in manga: MangaPage) -> Chapter? {
        if let sr = manga.startReading, let ch = manga.chapters.first(where: { $0.id == sr.chapterId }) {
            return ch
        }
        if manga.chapters.isEmpty { return nil }
        return manga.chapters.max { ($0.index ?? Int.min, $0.number) < ($1.index ?? Int.min, $1.number) }
    }

    @ViewBuilder
    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCapsule()
    }

    @ViewBuilder
    private func chapterSection(_ manga: MangaPage) -> some View {
        if !manga.chapters.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Chapters")
                    .font(.headline)
                ForEach(manga.chapters) { chapter in
                    NavigationLink(value: chapter) {
                        HStack {
                            Text(chapter.numberLabel)
                                .font(.body.bold())
                                .frame(width: 44, alignment: .leading)
                            Text(chapter.title)
                                .font(.body)
                                .lineLimit(1)
                            Spacer()
                            Text("\(chapter.pageCount) pp")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .glassCapsule()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let width = maxWidth.isFinite ? maxWidth : max(x - spacing, 0)
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x - bounds.minX + size.width > bounds.width, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}