import SwiftUI
import Core

/// Resolves a chapter's comment section id, then presents the standard
/// comments UI. The reader presents this instead of guessing a section id.
struct ChapterCommentsView: View {
    let chapterId: String
    @Environment(AppEnvironment.self) private var environment
    @State private var sectionId: String?
    @State private var failed = false

    var body: some View {
        Group {
            if let sectionId {
                CommentsView(sectionId: sectionId)
            } else if failed {
                ContentUnavailableView {
                    Label("Couldn't load comments", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("Retry") { Task { await resolve() } }
                }
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Comments")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task { if sectionId == nil, !failed { await resolve() } }
    }

    private func resolve() async {
        failed = false
        do {
            sectionId = try await environment.commentsRepository.commentSection(chapterId: chapterId).id
        } catch {
            failed = true
        }
    }
}
