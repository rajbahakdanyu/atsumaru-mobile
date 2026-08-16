import SwiftUI
import Kingfisher
import Core

struct ContinueReadingView: View {
    let items: [ContinueReadingItem]

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
                    NavigationLink(value: item.id) {
                        row(for: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: ContinueReadingItem) -> some View {
        HStack(spacing: 14) {
            KFImage(item.image.flatMap(ImageURLBuilder.poster))
                .resizable()
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

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCapsule()
    }

    private func resumeLabel(_ progress: ContinueReadingItem.ContinueReadingProgress) -> String {
        var parts: [String] = []
        if let mode = progress.mode, !mode.isEmpty { parts.append(mode.capitalized) }
        if let page = progress.page { parts.append("p.\(page)") }
        return parts.isEmpty ? "Continue" : parts.joined(separator: " · ")
    }
}