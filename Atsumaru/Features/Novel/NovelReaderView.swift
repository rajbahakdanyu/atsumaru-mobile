import SwiftUI
import MarkdownUI
import Core

struct NovelReaderView: View {
    let mangaId: String
    let chapter: Chapter

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @AppStorage("novelFontSize") private var fontSize: Double = 17
    @AppStorage("novelLineSpacing") private var lineSpacing: Double = 6
    @AppStorage("novelSerif") private var serif: Bool = false

    @State private var viewModel: NovelReaderViewModel?
    @State private var showSettings = false
    @State private var commentPopoverIndex: Int?

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
        .task {
            if viewModel == nil {
                viewModel = NovelReaderViewModel(
                    mangaId: mangaId,
                    chapter: chapter,
                    novelRepository: environment.novelRepository
                )
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func readerContent(novel: NovelChapter) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(Array(novel.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    paragraphRow(index: index, paragraph: paragraph, count: novel.paragraphComments?[String(index)])
                }
            }
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private func paragraphRow(index: Int, paragraph: String, count: Int?) -> some View {
        Markdown(paragraph)
            .font(.system(size: fontSize, design: serif ? .serif : .default))
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { commentPopoverIndex = index }
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
            .popover(isPresented: Binding(
                get: { commentPopoverIndex == index },
                set: { if !$0 { commentPopoverIndex = nil } }
            )) {
                VStack(spacing: 12) {
                    Text("\(count ?? 0) comments")
                        .font(.headline)
                    Text("Comments coming soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 240)
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { dismiss() } label: { Image(systemName: "xmark") }
        }
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