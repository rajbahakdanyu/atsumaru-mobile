import SwiftUI
import Kingfisher
import Core

struct MangaReaderView: View {
    let mangaId: String
    let chapter: Chapter

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.displayScale) private var displayScale

    @AppStorage("readerMode") private var storedMode: ReaderMode = .paged
    @AppStorage("readingDirection") private var readingDirection: String = "ltr"
    @AppStorage("readerFit") private var readerFit: ReaderFit = .fit

    @State private var viewModel: ReaderViewModel?
    @State private var zoomScale: CGFloat = 1.0
    @State private var showComments = false
    @State private var stripScrollTarget: Int?
    @State private var stripScrollActive = false
    @State private var stripViewportFrame: CGRect?
    @State private var stripSeekGateResetTask: Task<Void, Never>?
    // Reader chrome (nav bar + page slider) shows on launch/tap and
    // auto-hides after ~3s without interaction.
    @State private var showChrome = true
    @State private var chromeHideTask: Task<Void, Never>?
    // Pending auto-advance to the next chapter when lingering on the last page.
    @State private var advanceTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.loadFailed {
                    ContentUnavailableView {
                        Label("Couldn't load chapter", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Retry") { Task { await viewModel.load() } }
                    }
                } else if let readChapter = viewModel.readChapter {
                    readerContent(viewModel: viewModel, pages: readChapter.pages)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar { toolbarContent }
        // Chrome visibility follows `showChrome`; while visible the bar
        // keeps its material background so icons stay readable over light
        // pages, and it goes fully transparent when hidden.
        .toolbarBackground(showChrome ? .visible : .hidden, for: .navigationBar)
        .toolbar(showChrome ? .visible : .hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if viewModel == nil {
                let vm = ReaderViewModel(
                    mangaId: mangaId,
                    chapter: chapter,
                    readRepository: environment.readRepository,
                    progressStore: environment.progressStore,
                    downloadManager: environment.downloadManager,
                    mangaRepository: environment.mangaRepository
                )
                vm.mode = storedMode
                viewModel = vm
            }
            await viewModel?.load()
        }
        .onChange(of: storedMode) { _, newMode in
            viewModel?.mode = newMode
            scheduleChromeHide()
        }
        .onDisappear {
            viewModel?.saveProgressNow()
            chromeHideTask?.cancel()
            advanceTask?.cancel()
        }
        .sheet(isPresented: $showComments) {
            NavigationStack {
                ChapterCommentsView(chapterId: viewModel?.chapter.id ?? chapter.id)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Reading the comments shouldn't auto-advance the chapter out from
        // under the sheet; the user re-arms advance naturally by turning pages.
        .onChange(of: showComments) { _, presenting in
            if presenting { advanceTask?.cancel() }
        }
    }

    @ViewBuilder
    private func readerContent(viewModel: ReaderViewModel, pages: [PageImage]) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { viewport in
                if viewModel.mode == .strip {
                    stripReader(viewModel: viewModel, pages: pages, viewportWidth: viewport.size.width)
                } else {
                    pagedReader(viewModel: viewModel, pages: pages)
                }
            }
            if pages.count > 1 {
                VStack {
                    Spacer()
                    if showChrome {
                        pageSlider(viewModel: viewModel, total: pages.count)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }
                }
            }
        }
        .onAppear {
            scheduleChromeHide()
        }
    }

    @ViewBuilder
    private func pagedReader(viewModel: ReaderViewModel, pages: [PageImage]) -> some View {
        ZStack {
            TabView(selection: Binding(
                get: { viewModel.currentPage },
                set: { viewModel.currentPage = $0 }
            )) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageCell(page, index: index, viewModel: viewModel)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.currentPage) { _, _ in
                viewModel.scheduleProgressSave()
                zoomScale = 1.0
                scheduleChromeHide()
                handlePageChange(viewModel: viewModel, total: pages.count)
            }

            tapZones(viewModel: viewModel, total: pages.count)
        }
    }

    @ViewBuilder
    private func stripReader(viewModel: ReaderViewModel, pages: [PageImage], viewportWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        fitImage(readerPageImage(
                            viewModel: viewModel,
                            page: page,
                            index: index,
                            viewportWidth: viewportWidth
                        ))
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .id(page.id)
                            .background {
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: StripRowFramesKey.self,
                                        value: [index: geo.frame(in: .global)]
                                    )
                                }
                            }
                    }
                }
                .padding(.top, 4)
            }
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: StripViewportFrameKey.self, value: geo.frame(in: .global))
                }
            }
            .onPreferenceChange(StripViewportFrameKey.self) { frame in
                stripViewportFrame = frame
            }
            .onPreferenceChange(StripRowFramesKey.self) { frames in
                updateStripPage(frames: frames, viewModel: viewModel)
            }
            .onChange(of: stripScrollTarget) { _, target in
                guard let target, pages.indices.contains(target) else {
                    stripScrollTarget = nil
                    return
                }
                viewModel.currentPage = target
                withAnimation { proxy.scrollTo(pages[target].id, anchor: .top) }
                stripSeekGateResetTask?.cancel()
                stripSeekGateResetTask = Task {
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    if stripScrollTarget == target { stripScrollTarget = nil }
                }
            }
            .onScrollPhaseChange { _, newPhase in
                switch newPhase {
                case .tracking, .interacting, .decelerating:
                    // The user has seized the scroll view — hand control back so
                    // their manual scroll updates the page immediately.
                    stripScrollTarget = nil
                    stripScrollActive = true
                    hideChromeNow()
                case .idle:
                    stripScrollActive = false
                    stripScrollTarget = nil
                    showChromeAndScheduleHide()
                default:
                    stripScrollActive = true
                }
            }
            .onAppear {
                stripScrollActive = false
                stripScrollTarget = nil
                stripSeekGateResetTask?.cancel()
            }
            .onDisappear {
                stripSeekGateResetTask?.cancel()
            }
            .contentShape(Rectangle())
            // Strip mode has no page-tap zones; a tap anywhere toggles the
            // reader chrome.
            .onTapGesture { toggleChrome() }
        }
    }

    private func updateStripPage(frames: [Int: CGRect], viewModel: ReaderViewModel) {
        guard stripScrollTarget == nil,
              stripScrollActive,
              let viewport = stripViewportFrame else { return }
        guard let index = stripCenterIndex(frames: frames, centerY: viewport.midY),
              index != viewModel.currentPage else { return }
        viewModel.currentPage = index
        viewModel.scheduleProgressSave()
        handlePageChange(viewModel: viewModel, total: viewModel.readChapter?.pages.count ?? 0)
    }

    private func stripCenterIndex(frames: [Int: CGRect], centerY: CGFloat) -> Int? {
        var nearestAbove: (index: Int, maxY: CGFloat)?
        var topmost: (index: Int, minY: CGFloat)?
        for (index, frame) in frames {
            if frame.minY <= centerY, centerY < frame.maxY { return index }
            if frame.maxY <= centerY, nearestAbove.map({ frame.maxY > $0.maxY }) ?? true {
                nearestAbove = (index, frame.maxY)
            }
            if topmost.map({ frame.minY < $0.minY }) ?? true {
                topmost = (index, frame.minY)
            }
        }
        return nearestAbove?.index ?? topmost?.index
    }

    private struct StripRowFramesKey: PreferenceKey {
        static let defaultValue: [Int: CGRect] = [:]
        static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
            value.merge(nextValue(), uniquingKeysWith: { current, _ in current })
        }
    }

    private struct StripViewportFrameKey: PreferenceKey {
        static let defaultValue: CGRect = .zero
        static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
            value = nextValue()
        }
    }

    @ViewBuilder
    private func fitImage(_ image: KFImage) -> some View {
        if readerFit == .fit {
            image.scaledToFit()
        } else {
            image.scaledToFill()
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { zoomScale = max(1.0, min(4.0, $0)) }
            .onEnded { _ in
                if zoomScale < 1.0 { zoomScale = 1.0 }
            }
            .simultaneously(with: TapGesture().onEnded { zoomScale = zoomScale > 1 ? 1 : 2 })
    }

    @ViewBuilder
    private func pageCell(_ page: PageImage, index: Int, viewModel: ReaderViewModel) -> some View {
        GeometryReader { proxy in
            let baseWidth = proxy.size.width
            let baseHeight: CGFloat = readerFit == .fill
                ? proxy.size.height
                : baseWidth / CGFloat(page.aspectRatio)
            ScrollView([.vertical]) {
                fitImage(readerPageImage(
                    viewModel: viewModel,
                    page: page,
                    index: index,
                    viewportWidth: proxy.size.width
                ))
                    .frame(width: baseWidth * zoomScale, height: baseHeight * zoomScale)
                    .clipped()
                    .gesture(zoomGesture)
                    .frame(maxWidth: .infinity)
            }
            // Vertical micro-scroll is reserved for the zoomed state; at
            // natural size the vertical axis stays locked so a drag never
            // fights the horizontal page turn.
            .scrollDisabled(zoomScale <= 1.0)
        }
    }

    /// Builds the page image for a row: local file URLs are served from disk
    /// via `LocalFileImageDataProvider`, remote pages go through the network
    /// URL builder. Both share the same downsampling/layout pipeline.
    private func readerPageImage(viewModel: ReaderViewModel, page: PageImage, index: Int, viewportWidth: CGFloat) -> KFImage {
        if let localPageURLs = viewModel.localPageURLs, localPageURLs.indices.contains(index) {
            return KFImage.readerPage(
                localFile: localPageURLs[index],
                viewportWidth: viewportWidth,
                aspectRatio: page.aspectRatio,
                displayScale: displayScale
            )
        }
        return KFImage.readerPage(
            ImageURLBuilder.page(page.image),
            viewportWidth: viewportWidth,
            aspectRatio: page.aspectRatio,
            displayScale: displayScale
        )
    }

    @ViewBuilder
    private func tapZones(viewModel: ReaderViewModel, total: Int) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { navigate(viewModel: viewModel, delta: -1, total: total) }
                .frame(maxWidth: .infinity)
            Color.clear
                .frame(width: 80)
                .contentShape(Rectangle())
                // Center tap toggles the chrome (standard reader behavior);
                // the flanks turn pages.
                .onTapGesture { toggleChrome() }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { navigate(viewModel: viewModel, delta: 1, total: total) }
                .frame(maxWidth: .infinity)
        }
        .allowsHitTesting(zoomScale <= 1.0)
    }

    private func navigate(viewModel: ReaderViewModel, delta: Int, total: Int) {
        let forward = readingDirection == "ltr" ? delta > 0 : delta < 0
        let step = forward ? 1 : -1
        let target = viewModel.currentPage + step
        if total > 0, (0..<total).contains(target) {
            viewModel.currentPage = target
        }
    }

    /// When the reader lands on the final page and a next chapter exists,
    /// auto-advance after a short pause; any page change away from the last
    /// page cancels the pending advance.
    private func handlePageChange(viewModel: ReaderViewModel, total: Int) {
        let onLastPage = total > 0 && viewModel.currentPage == total - 1
        if onLastPage, let next = viewModel.nextChapter {
            advanceTask?.cancel()
            advanceTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                await viewModel.switchChapter(to: next)
            }
        } else {
            advanceTask?.cancel()
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

    /// Scroll feedback: chrome vanishes the moment scrolling starts.
    private func hideChromeNow() {
        chromeHideTask?.cancel()
        chromeHideTask = nil
        if showChrome {
            withAnimation(.easeInOut(duration: 0.2)) { showChrome = false }
        }
    }

    /// Scroll settled: chrome returns and re-arms the 3 s auto-hide.
    private func showChromeAndScheduleHide() {
        withAnimation(.easeInOut(duration: 0.2)) { showChrome = true }
        scheduleChromeHide()
    }

    /// Auto-hides the chrome ~3s after the last reading interaction; every
    /// interaction path calls this again to reschedule.
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

    @ViewBuilder
    private func pageSlider(viewModel: ReaderViewModel, total: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(viewModel.currentPage + 1)")
                .font(.body.monospacedDigit())
                .fixedSize()
                .frame(minWidth: 36, alignment: .trailing)
            Slider(value: Binding(
                get: { Double(viewModel.currentPage) },
                set: { newValue in
                    let page = Int(newValue.rounded())
                    viewModel.currentPage = page
                    if viewModel.mode == .strip {
                        stripScrollTarget = page
                    }
                }
            ), in: 0...Double(max(0, total - 1)), onEditingChanged: { editing in
                // Hold the chrome while scrubbing; restart the auto-hide
                // timer when the drag ends.
                if editing {
                    chromeHideTask?.cancel()
                } else {
                    scheduleChromeHide()
                }
            })
            Text("\(total)")
                .font(.body.monospacedDigit())
                .fixedSize()
                .frame(minWidth: 36, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(viewModel?.readChapter?.title ?? chapter.title)
                .font(.subheadline.bold())
                .lineLimit(1)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showComments = true } label: {
                Image(systemName: "bubble.left.and.bubble.right")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Mode", selection: $storedMode) {
                    Label("Paged", systemImage: "book").tag(ReaderMode.paged)
                    Label("Webtoon", systemImage: "rectangle.split.1x2").tag(ReaderMode.strip)
                }
                if storedMode != .strip {
                    // Direction/fit only affect paged pages; they were
                    // previously stored with no UI to change them.
                    Picker("Reading direction", selection: $readingDirection) {
                        Label("Left to right", systemImage: "arrow.right").tag("ltr")
                        Label("Right to left", systemImage: "arrow.left").tag("rtl")
                    }
                    Picker("Page fit", selection: $readerFit) {
                        Label("Fit width", systemImage: "arrow.up.left.and.arrow.down.right").tag(ReaderFit.fit)
                        Label("Fill screen", systemImage: "arrow.down.right.and.arrow.up.left").tag(ReaderFit.fill)
                    }
                }
            } label: {
                Image(systemName: storedMode == .strip ? "rectangle.split.1x2" : "book")
            }
        }
    }
}