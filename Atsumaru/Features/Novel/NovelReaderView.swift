import SwiftUI
import Textual
import Core

struct NovelReaderView: View {
    let mangaId: String
    let chapter: Chapter

    @Environment(AppEnvironment.self) private var environment

    @AppStorage("novelFontSize") private var fontSize: Double = 17
    @AppStorage("novelLineSpacing") private var lineSpacing: Double = 6
    @AppStorage("novelSerif") private var serif: Bool = false

    @State private var viewModel: NovelReaderViewModel?
    @State private var showSettings = false
    @State private var commentPopover: ParagraphIndex?
    @State private var hasUserScrolled = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.loadFailed {
                    ContentUnavailableView {
                        Label("Couldn't load chapter", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Retry") { Task { await viewModel.load() } }
                    }
                } else if let novel = viewModel.novel {
                    readerContent(novel: novel)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar { toolbarContent }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if viewModel == nil {
                viewModel = NovelReaderViewModel(
                    mangaId: mangaId,
                    chapter: chapter,
                    novelRepository: environment.novelRepository,
                    readRepository: environment.readRepository,
                    progressStore: environment.progressStore,
                    downloadManager: environment.downloadManager
                )
            }
            await viewModel?.load()
        }
        .onDisappear {
            viewModel?.saveProgressNow()
        }
        .sheet(item: $commentPopover) {
            ParagraphCommentsSheet(chapterId: chapter.id, paragraph: $0.value)
        }
    }

    @ViewBuilder
    private func readerContent(novel: NovelChapter) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(novel.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        paragraphRow(index: index, paragraph: paragraph, count: novel.paragraphComments?[String(index)])
                            .id(index)
                            .onScrollVisibilityChange(threshold: 0.5) { visible in
                                guard visible, hasUserScrolled else { return }
                                viewModel?.currentParagraph = index
                                viewModel?.scheduleProgressSave()
                            }
                    }
                }
                .padding(.vertical, 24)
            }
            .onChange(of: novel.id, initial: true) { _, _ in
                // `novel` is assigned before this subtree is created, so the id
                // never changes while the reader is visible; `initial: true` is
                // what makes the restore actually run on first appearance. The
                // jump is deferred past the first layout pass because the scroll
                // view has not laid out its content yet at `initial` evaluation,
                // and it re-checks `hasUserScrolled` so a re-shown view never
                // re-jumps after the user has scrolled away.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.05))
                    guard let vm = viewModel, !hasUserScrolled, vm.currentParagraph > 0 else { return }
                    proxy.scrollTo(vm.currentParagraph, anchor: .top)
                }
            }
            .onScrollPhaseChange { _, newPhase in
                if newPhase == .tracking || newPhase == .interacting {
                    hasUserScrolled = true
                }
            }
        }
    }

    @ViewBuilder
    private func paragraphRow(index: Int, paragraph: String, count: Int?) -> some View {
        InlineText(markdown: MarkdownSanitizer.sanitizeImages(paragraph))
            .font(.system(size: fontSize, design: serif ? .serif : .default))
            .textual.lineSpacing(.fontScaled(lineSpacing / fontSize))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { commentPopover = ParagraphIndex(value: index) }
            .overlay(alignment: .topTrailing) {
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .glassCapsule()
                        .padding(.top, 2)
                        .padding(.trailing, 4)
                }
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(viewModel?.novel?.title ?? chapter.title)
                .font(.subheadline.bold())
                .lineLimit(1)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showSettings = true } label: { Image(systemName: "textformat") }
                .popover(isPresented: $showSettings) {
                    settingsPanel
                }
        }
    }

    @ViewBuilder
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Typography").font(.headline)
            HStack {
                Text("Font size")
                Slider(value: $fontSize, in: 12...28, step: 1)
                Text("\(Int(fontSize))")
                    .font(.body.monospacedDigit())
                    .frame(width: 28, alignment: .trailing)
            }
            HStack {
                Text("Line spacing")
                Slider(value: $lineSpacing, in: 0...14, step: 1)
                Text("\(Int(lineSpacing))")
                    .font(.body.monospacedDigit())
                    .frame(width: 28, alignment: .trailing)
            }
            Toggle("Serif font", isOn: $serif)
        }
        .padding(20)
        .frame(width: 300)
        .presentationCompactAdaptation(.popover)
    }
}

private struct ParagraphIndex: Identifiable {
    let value: Int
    var id: Int { value }
}