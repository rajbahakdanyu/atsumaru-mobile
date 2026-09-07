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
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    resumeRow(item)
                    Divider()
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Mirrors the website: tapping the row opens the manga detail, the play
    /// button resumes directly into the reader at the saved chapter. One row
    /// archetype for resumable and non-resumable items.
    @ViewBuilder
    private func resumeRow(_ item: ContinueReadingItem) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: item.id) {
                HStack(spacing: 12) {
                    KFImage.poster(item.image.flatMap(ImageURLBuilder.poster), displayScale: displayScale)
                        .scaledToFill()
                        .frame(width: 48, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: Poster.thumbCornerRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title ?? "Untitled")
                            .font(.subheadline)
                            .lineLimit(1)
                        if let progress = item.continueReading {
                            Text(subtitle(progress))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if let status = item.bookmarkStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            if let chapterId = item.continueReading?.chapterId {
                NavigationLink(value: ReaderResume(
                    mangaId: item.id,
                    chapter: Chapter(id: chapterId),
                    isNovel: item.medium == "Novel"
                )) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Resume reading")
            }
        }
        .padding(.vertical, 6)
    }

    private func subtitle(_ progress: ContinueReadingItem.ContinueReadingProgress) -> String {
        var parts: [String] = []
        if let mode = progress.mode, !mode.isEmpty { parts.append(mode.capitalized) }
        if let page = progress.page { parts.append("p.\(page)") }
        return parts.isEmpty ? "Continue" : parts.joined(separator: " · ")
    }
}