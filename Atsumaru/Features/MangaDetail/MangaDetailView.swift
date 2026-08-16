import SwiftUI
import Core
import Kingfisher

struct MangaDetailView: View {
    let mangaId: String
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: MangaDetailViewModel?

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
                hero(manga)
                titleSection(manga)
                startReadingButton(for: manga)
                metaChips(manga)
                if let synopsis = manga.synopsis, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.body)
                        .padding(.horizontal, 16)
                }
                tagSection(manga)
                chapterSection(manga)
                relatedSection(manga)
            }
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func hero(_ manga: MangaPage) -> some View {
        ZStack {
            if let banner = manga.banner, let url = ImageURLBuilder.poster(banner.url) {
                Color.clear
                    .aspectRatio(CGFloat(banner.aspectRatio), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        KFImage(url)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else if let path = manga.poster?.image, let url = ImageURLBuilder.poster(path) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.thinMaterial)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(manga.title)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect)
        }
    }

    @ViewBuilder
    private func titleSection(_ manga: MangaPage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(manga.title)
                .font(.title2.bold())
            if let alt = manga.englishTitle, !alt.isEmpty {
                Text(alt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !manga.authors.isEmpty {
                Text(manga.authors.map(authorLabel).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    private func authorLabel(_ author: Author) -> String {
        if let type = author.type, !type.isEmpty {
            return "\(author.name) · \(type)"
        }
        return author.name
    }

    @ViewBuilder
    private func metaChips(_ manga: MangaPage) -> some View {
        let labels = [manga.status, manga.type, manga.medium]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        if !labels.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(labels, id: \.self) { chip($0) }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func tagSection(_ manga: MangaPage) -> some View {
        let genres = manga.genres
        let tags = manga.tags
        if !genres.isEmpty || !tags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !genres.isEmpty {
                    chipRow(title: "Genres", tags: genres.map(\.name))
                }
                if !tags.isEmpty {
                    chipRow(title: "Tags", tags: tags.map(\.name))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func chipRow(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { chip($0) }
            }
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
                            Text("\(chapter.number)")
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

    @ViewBuilder
    private func relatedSection(_ manga: MangaPage) -> some View {
        let recs = manga.recommendations
        if !recs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommended")
                    .font(.headline)
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(recs) { Poster(item: $0) }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func startReadingButton(for manga: MangaPage) -> some View {
        if let chapter = startReadingChapter(in: manga) {
            NavigationLink(value: chapter) {
                Label("Start Reading", systemImage: "book.fill")
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
        return manga.chapters.min { ($0.index ?? Int.max, $0.number) < ($1.index ?? Int.max, $1.number) }
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