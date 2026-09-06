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
    // Reader chrome (nav bar) shows on launch/tap and auto-hides after ~3s
    // without interaction, like the manga reader.
    @State private var showChrome = true
    @State private var chromeHideTask: Task<Void, Never>?

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
        // While visible the bar keeps its material background so the chapter
        // title stays readable over light paragraphs; transparent when hidden.
        .toolbarBackground(showChrome ? .visible : .hidden, for: .navigationBar)
        .toolbar(showChrome ? .visible : .hidden, for: .navigationBar)
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
            chromeHideTask?.cancel()
        }
        .sheet(item: $commentPopover) {
            ParagraphCommentsSheet(chapterId: chapter.id, paragraph: $0.value)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            settingsPanel
                .presentationDetents([.fraction(0.35)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            scheduleChromeHide()
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
                    scheduleChromeHide()
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
            // Reading tap toggles the chrome; comments live on the dedicated
            // trailing affordance so paragraph taps never open sheets by accident.
            .onTapGesture { toggleChrome() }
            .overlay(alignment: .topTrailing) {
                Button {
                    commentPopover = ParagraphIndex(value: index)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left")
                        if let count, count > 0 {
                            Text("\(count)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Paragraph comments")
                .padding(.top, 2)
                .padding(.trailing, 4)
            }
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showChrome.toggle()
        }
        if showChrome {
            scheduleChromeHide()
        } else {
            chromeHideTask?.cancel()
            chromeHideTask = nil
        }
    }

    /// Auto-hides the chrome ~3s after the last reading interaction.
    private func scheduleChromeHide() {
        chromeHideTask?.cancel()
        guard showChrome else { return }
        chromeHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showChrome = false
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
        .frame(maxWidth: .infinity, alignment: .leading)
        // Presented as a bottom sheet on every size class (fraction detent);
        // the fixed-300pt popover was cramped on iPhone at large Dynamic Type.
    }
}

private struct ParagraphIndex: Identifiable {
    let value: Int
    var id: Int { value }
}