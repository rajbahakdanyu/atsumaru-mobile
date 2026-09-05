import SwiftUI
import Kingfisher
import Core

struct MangaReaderView: View {
    let mangaId: String
    let chapter: Chapter

    @Environment(AppEnvironment.self) private var environment

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
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if viewModel == nil {
                let vm = ReaderViewModel(
                    mangaId: mangaId,
                    chapter: chapter,
                    readRepository: environment.readRepository,
                    progressStore: environment.progressStore
                )
                vm.mode = storedMode
                viewModel = vm
            }
            await viewModel?.load()
        }
        .onChange(of: storedMode) { _, newMode in
            viewModel?.mode = newMode
        }
        .onDisappear {
            viewModel?.saveProgressNow()
        }
        .sheet(isPresented: $showComments) {
            NavigationStack {
                CommentsView(sectionId: "manga:\(mangaId)")
            }
        }
    }

    @ViewBuilder
    private func readerContent(viewModel: ReaderViewModel, pages: [PageImage]) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if viewModel.mode == .strip {
                stripReader(viewModel: viewModel, pages: pages)
            } else {
                pagedReader(viewModel: viewModel, pages: pages)
            }
            if pages.count > 1 {
                VStack {
                    Spacer()
                    pageSlider(viewModel: viewModel, total: pages.count)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
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
                    pageCell(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.currentPage) { _, _ in
                viewModel.scheduleProgressSave()
                zoomScale = 1.0
            }

            tapZones(viewModel: viewModel, total: pages.count)
        }
    }

    @ViewBuilder
    private func stripReader(viewModel: ReaderViewModel, pages: [PageImage]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        fitImage(KFImage(ImageURLBuilder.page(page.image)).resizable())
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
                guard let target, pages.indices.contains(target) else { return }
                viewModel.currentPage = target
                withAnimation { proxy.scrollTo(pages[target].id, anchor: .top) }
                stripSeekGateResetTask?.cancel()
                stripSeekGateResetTask = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    if stripScrollTarget == target { stripScrollTarget = nil }
                }
            }
            .onScrollPhaseChange { _, newPhase in
                stripScrollActive = newPhase != .idle
                if newPhase == .idle {
                    stripScrollTarget = nil
                }
            }
            .onAppear {
                stripScrollActive = false
                stripScrollTarget = nil
                stripSeekGateResetTask?.cancel()
            }
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
    private func pageCell(_ page: PageImage) -> some View {
        GeometryReader { proxy in
            let baseWidth = proxy.size.width
            let baseHeight: CGFloat = readerFit == .fill
                ? proxy.size.height
                : baseWidth / CGFloat(page.aspectRatio)
            ScrollView([.vertical]) {
                fitImage(KFImage(ImageURLBuilder.page(page.image)).resizable())
                    .frame(width: baseWidth * zoomScale, height: baseHeight * zoomScale)
                    .clipped()
                    .gesture(zoomGesture)
                    .frame(maxWidth: .infinity)
            }
        }
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
                .allowsHitTesting(false)
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

    @ViewBuilder
    private func pageSlider(viewModel: ReaderViewModel, total: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(viewModel.currentPage + 1)")
                .font(.body.monospacedDigit())
                .frame(width: 36, alignment: .trailing)
            Slider(value: Binding(
                get: { Double(viewModel.currentPage) },
                set: { newValue in
                    let page = Int(newValue.rounded())
                    viewModel.currentPage = page
                    if viewModel.mode == .strip {
                        stripScrollTarget = page
                    }
                }
            ), in: 0...Double(max(0, total - 1)))
            Text("\(total)")
                .font(.body.monospacedDigit())
                .frame(width: 36, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCapsule()
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
                Button { storedMode = .paged } label: { Label("Paged", systemImage: "book") }
                Button { storedMode = .strip } label: { Label("Webtoon", systemImage: "rectangle.split.1x2") }
            } label: {
                Image(systemName: storedMode == .strip ? "rectangle.split.1x2" : "book")
            }
        }
    }
}