import SwiftUI
import Kingfisher
import Core

struct ContinueReadingView: View {
    let items: [ContinueReadingItem]

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView {
                Label("Nothing to continue", systemImage: "book")
            } description: {
                Text("Manga you keep reading will show up here.")
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    resumeRow(item)
                }
            }
        }
    }

    /// Mirrors the website: tapping the row opens the manga detail, the play
    /// button resumes directly into the reader at the saved chapter.
    @ViewBuilder
    private func resumeRow(_ item: ContinueReadingItem) -> some View {
        if let chapterId = item.continueReading?.chapterId {
            HStack(spacing: 10) {
                NavigationLink(value: item.id) {
                    rowContent(for: item, showsChevron: false)
                }
                .buttonStyle(.plain)
                NavigationLink(value: ReaderResume(
                    mangaId: item.id,
                    chapter: Chapter(id: chapterId),
                    isNovel: item.medium == "Novel"
                )) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Resume reading")
            }
            .padding(.horizontal, 12)
            .glassCapsule()
        } else {
            NavigationLink(value: item.id) {
                rowContent(for: item, showsChevron: true)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func rowContent(for item: ContinueReadingItem, showsChevron: Bool) -> some View {
        HStack(spacing: 14) {
            KFImage.poster(item.image.flatMap(ImageURLBuilder.poster), displayScale: displayScale)
                .scaledToFill()
                .frame(width: 64, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)

                if let status = item.bookmarkStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let progress = item.continueReading {
                    HStack(spacing: 6) {
                        Image(systemName: item.medium == "Novel" ? "text.book.closed" : "book.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(resumeLabel(progress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resumeLabel(_ progress: ContinueReadingItem.ContinueReadingProgress) -> String {
        var parts: [String] = []
        if let mode = progress.mode, !mode.isEmpty { parts.append(mode.capitalized) }
        if let page = progress.page { parts.append("p.\(page)") }
        return parts.isEmpty ? "Continue" : parts.joined(separator: " · ")
    }
}