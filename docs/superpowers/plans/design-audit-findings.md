# Design/UX Audit Findings — atsumaru-mobile

Audit of every screen in code (device behavior reasoned from code; app not run).
Checklist source: `.superpowers/sdd/task-5-brief.md`. Feed top findings into Task 7 polish passes.

Severity: **high** = broken/likely-broken UI or drives a dedicated pass · **med** = clear inconsistency vs. the checklist · **low** = polish.

---

## Top 15 (severity-ordered, cross-screen)

| # | Finding | Where | Sev |
|---|---------|-------|-----|
| 1 | `ForumView` toolbar (compose button + adult-channels menu) is attached **outside** the `NavigationStack` (`NavigationStack { … }.toolbar { … }`). Toolbar items are resolved from inside the stack's content; as written the compose + filter buttons most likely never render on the Forum screen. Verify on device, then move `.toolbar` onto the content branches inside the stack. | ForumView.swift:47-70 | high |
| 2 | Manga reader chrome never hides: nav bar and page slider are permanently visible, no tap-to-toggle. With `.toolbarBackground(.hidden)` the white toolbar icons sit directly on the page art — unreadable over light pages. Fix: toggle a `showChrome` state on tap, `if showChrome` the slider + `.toolbar(showChrome ? .visible : .hidden, for: .navigationBar)`. | MangaReaderView.swift:43, 84-91 | high |
| 3 | Novel reader body text scrolls **under** a fully transparent nav bar (`toolbarBackground(.hidden)`) — chapter title collides with paragraph text. Same chrome-toggle fix as #2, or restore the bar background for this screen. | NovelReaderView.swift:38-41 | high |
| 4 | `glassCapsule` used on ~14 inline element sites across 9 screens (chips, list rows, stat tiles, badges, form fields) — the brief reserves it for floating chrome only. Full list + replacements in the per-screen tables; single biggest driver of pass 2. | FilterSheet, LibraryView, ContinueReadingView, PostDetailView, MangaDetailView, AccountView, CommentsView, NovelReaderView, AuthFlowView | high |
| 5 | Custom `EmptyStateView` (glass tray card) used on 8 sites in Browse/Library/Forum while Downloads/ListDetail/AddToList/ContinueReading use native `ContentUnavailableView` — two competing empty-state systems. Replace all `EmptyStateView` call sites with `ContentUnavailableView(icon/title/description)` and delete `EmptyStateView.swift`. | BrowseView.swift:146,162 · LibraryView.swift:95,120,167 · ForumView.swift:105,284 | med |
| 6 | Five sheets ship with no `presentationDetents` (default `.large`) and no explicit grabber: Compose (ForumView.swift:88, ForumView.swift:263), EditPost (PostDetailView.swift:165), AddToList (MangaDetailView.swift:92 — brief wants `.medium`+), manga comments (MangaReaderView.swift:66), paragraph comments (NovelReaderView.swift:58). | see left | med |
| 7 | Browse root tab: `.navigationBarTitleDisplayMode(.inline)` + segmented picker in `.principal` means the "Browse" title is never visible — the only root tab without a large title (checklist #1 violation). Restore large title and move the picker into a pinned header row (or accept and document the exception). | BrowseView.swift:68-78 | med |
| 8 | Two dead reader settings: `readingDirection` and `readerFit` are read from `@AppStorage` but no UI anywhere writes them — LTR/fit are permanently locked with no way for users to change them. Add toggles to the reader menu (or DownloadSettings-style panel) or delete the settings. | MangaReaderView.swift:13-14 | med |
| 9 | Library history and Continue Reading render card rows (glass capsules) in a `ScrollView`+`LazyVStack` — row-based screens should be `List` (checklist #4); glass on every row is heavy and loses swipe/separator affordances. | LibraryView.swift:124-133, 293 · ContinueReadingView.swift:18-50 | med |
| 10 | `ListDetailView` masks every failure as `ErrorStateView(error: .decoding)` — offline/401/429 all show "Something went wrong" instead of "You're offline". Capture the real `ApiError`. | ListDetailView.swift:35, 50-52 | med |
| 11 | Comments empty states are plain centered `Text("No comments yet")` in both the manga comments sheet and paragraph comments sheet, inconsistent with `ContentUnavailableView` elsewhere (checklist #5). | CommentsView.swift:66-71 · ParagraphCommentsSheet.swift:41-44 | med |
| 12 | Forum adult-channels toggle uses the `18.circle` SF symbol (explicitly called out in the brief) and the whole menu masquerades behind the filter icon; a settings/toggle menu should not use the filter semantics. | ForumView.swift:64-67 | med |
| 13 | Auth sheet `.presentationDetents([.medium])`: the login form + keyboard barely fit at medium, and "Forgot password" pushes a full `Form` inside the cramped sheet. Use `.large` (or `[.large]` with drag indicator). | AuthFlowView.swift:11 | med |
| 14 | `Poster` title uses a hard `.frame(width: 108, height: 32)` — truncates/clips at accessibility text sizes; and three divergent poster cells exist (Poster 2-line vs LibraryView/ListDetailView 1-line custom). Unify on `Poster(showsTitle: true)` and drop the fixed height. | Poster.swift:22-24 · LibraryView.swift:253-263 · ListDetailView.swift:56-66 | med |
| 15 | `ForumView` sets `navigationTitle` only on the signed-in `List` branch and the signed-out branch — during loading skeleton and error states the nav bar title is blank. Attach `.navigationTitle("Forum")` once to the shared container. | ForumView.swift:98-116, 128-133 | med |

---

## Shared / DesignSystem

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Custom glass-card `EmptyStateView` competes with native `ContentUnavailableView` used elsewhere | EmptyStateView.swift:3-21 | med | Replace call sites with `ContentUnavailableView`; delete file |
| Glass card + `.glassProminent` Retry = glass-on-glass; heavy gray box on plain backgrounds | ErrorStateView.swift:18-22 | med | Drop `.glassEffect`; use `ContentUnavailableView` with a Retry action, or plain card with `.borderedProminent` |
| Fixed `height: 32` on poster title truncates Dynamic Type at accessibility sizes | Poster.swift:24 | med | Remove height; `.frame(width: 108, alignment: .topLeading)` + `fixedSize(horizontal: false, vertical: true)` |
| `glassCapsule` bakes in `.interactive()` — passive decorations (rows, badges, stat tiles) get interactive-glass treatment they don't need | Glass.swift:6 | low | Split into `glassCapsule(interactive: Bool = false)` or drop `.interactive()` |
| EmptyState icon `.system(size: 40)` fixed — doesn't scale with Dynamic Type | EmptyStateView.swift:9 | low | `.font(.largeTitle)` (moot if replaced by ContentUnavailableView) |
| ErrorState icon `.system(size: 40)` fixed | ErrorStateView.swift:11 | low | `.font(.largeTitle)` |
| SignedOutView icon `.system(size: 52)` fixed | SignedOutView.swift:10 | low | `.font(.system(.largeTitle))` variant or `.largeTitle` |
| Three divergent poster cells: Poster (2-line title), LibraryView bookmarkCell (1-line), ListDetailView posterCard (1-line) | Poster.swift:12-26 · LibraryView.swift:253-263 · ListDetailView.swift:56-66 | low | Reuse `Poster(showsTitle: true)` in all three |
| Corner radius drift: 10 (Poster/detail header), 8 (ContinueReading/Downloads), 6 (history thumb) | Poster.swift:17 · ContinueReadingView.swift:65 · LibraryView.swift:271 · DownloadsView.swift:123 | low | Pick one radius token (8 or 10) for thumbs |
| RootView tabs: fill-variant icons, minimize-on-scroll — no findings; good | RootView.swift:5-12 | — | — |

## Browse (BrowseView + poster grid + empty states)

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Root tab uses `.inline` + segmented picker in `.principal` — "Browse" title never renders (only root tab without large title) | BrowseView.swift:68-78 | med | Restore large title; move picker to a pinned section header or keep inline as a documented exception |
| Custom EmptyStateView for "no filters applied" and "no results" | BrowseView.swift:146, 162 | med | `ContentUnavailableView("No filters applied", systemImage: "line.3.horizontal.decrease.circle", description:…)` / `(…, systemImage: "magnifyingglass")` |
| Filter/Search sheets have `.presentationDetents([.large])` but no explicit grabber | BrowseView.swift:94, 107 | med | Add `.presentationDragIndicator(.visible)` to both sheets |
| Extra wrapper `VStack(spacing: 12)` around a single EmptyStateView | BrowseView.swift:145-148 | low | Delete wrapper |
| Grid spacing 16 here vs 12 in ListDetailView for the same poster grid | BrowseView.swift:166 | low | Standardize on PosterGrid (add spacing to `PosterGrid`) |
| Icons + refreshable + pagination: magnifyingglass / line.3.horizontal.decrease.circle correct; no violations | BrowseView.swift:79-86 | — | — |

## FilterSheet

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| `glassCapsule` on all inline controls: sort/status menu capsules, tag search field, selected-tag chips, tag rows, genre/type/status chips (5 sites) | FilterSheet.swift:89, 155, 197, 224, 283 | med | Replace with `.background(.fill.quaternary, in: Capsule())` for chips/rows; menu labels as plain `LabeledContent` rows; search field as `.textFieldStyle(.roundedBorder)` |
| Nested `ScrollView` with `frame(maxHeight: 300)` inside the sheet's ScrollView — two competing scroll gestures | FilterSheet.swift:171-179 | low | Let tag rows flow in the outer scroll (FlowLayout) or use a fixed-height `List` |
| Dead `.background(Color.clear)` on ScrollView | FilterSheet.swift:35 | low | Delete |
| Section headers are `.subheadline` uppercase-secondary, not the `.title2.bold()` guideline | FilterSheet.swift:96-98 | low | Conform to checklist #8 or keep as documented sheet-local style |
| Tag search field lacks `.submitLabel(.search)` and focus handling | FilterSheet.swift:140-142 | low | Add `.submitLabel(.search)` |
| "Apply" always enabled even with zero changes | FilterSheet.swift:43-49 | low | Disable when `!viewModel.hasActiveFilters`, or relabel "Done" |
| Clear is `role: .destructive` — destructive styling for a non-destructive reset | FilterSheet.swift:40 | low | Plain button; destructive red implies data loss |

## SearchSheet

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Search field not focused on appear — user must tap first | SearchSheet.swift:13-17 | med | `@FocusState` + `.onAppear { focused = true }` (brief: search sheet should be type-ready) |
| "Search" with empty text silently clears ALL filters (q → "*" + clearFilters) | SearchSheet.swift:33-40 | low | Disable the Search button while trimmed text is empty, or confirm |
| No explicit grabber | SearchSheet.swift:9-30 | low | `.presentationDragIndicator(.visible)` |

## Library (4 segments)

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| `glassCapsule` on every history row — inline misuse | LibraryView.swift:293 | med | Plain rows (List) or `.background(.quaternary, in: RoundedRectangle(cornerRadius: 12))` |
| History is `ScrollView`+`LazyVStack` for row content (checklist #4 mismatch) — no separators/swipe | LibraryView.swift:124-133 | med | Convert to `List` with plain rows |
| Custom EmptyStateView ×3 ("No bookmarks" / "No history" / "No lists yet") | LibraryView.swift:95, 120, 167 | med | `ContentUnavailableView` with `bookmark`/`clock.arrow.circlepath`/`list.bullet` icons |
| Empty/error states embedded as List rows with glass card styling inside `.plain` List | LibraryView.swift:162-171 | low | `ContentUnavailableView` directly in the Section (it styles correctly in Lists) |
| bookmarkCell duplicates Poster with different truncation (1-line vs 2-line) | LibraryView.swift:253-263 | low | Use `Poster(item:showsTitle:)` (needs `HomeItem` shim or a second Poster init taking title/image) |
| Pinned indicator `pin.fill` + `.tint` here vs `star.fill` + `.yellow` in AddToListView for the same concept | LibraryView.swift:323-327 | low | Standardize on pin.fill + tint |
| New-list alert with TextField is fine (iOS 16+); delete confirmationDialog correct; action-error alert correct pattern | LibraryView.swift:204-242 | — | — |
| Root tab large title ✓ (no displayMode set); toolbar plus only on lists segment ✓ | LibraryView.swift:179, 193-203 | — | — |

## ListDetailView

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Every load failure surfaced as `ErrorStateView(error: .decoding)` — real error discarded (offline shows "Something went wrong") | ListDetailView.swift:35, 50-52 | med | Store `ApiError` from the catch and pass it through |
| Grid spacing 12 vs Browse's 16 | ListDetailView.swift:22 | low | Centralize in `PosterGrid` |
| No pull-to-refresh on the list grid | ListDetailView.swift:21 | low | Add `.refreshable` |
| Empty state uses native ContentUnavailableView ✓ | ListDetailView.swift:19 | — | — |

## AddToListView

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Sheet presented with no detents (brief: add-to-list = `.medium`+) and no grabber | MangaDetailView.swift:92-95 | med | `.presentationDetents([.medium, .large])` + `.presentationDragIndicator(.visible)` |
| Pinned lists marked `star.fill` + hardcoded `.yellow`, inconsistent with Library's pin.fill + tint | AddToListView.swift:74-77 | low | `pin.fill` + `.tint` to match LibraryView.swift:324 |
| Per-row status text ("Added"/"Already in list") is good inline error handling ✓ | AddToListView.swift:66-70, 93-96 | — | — |

## ContinueReadingView

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Every resume row wrapped in `glassCapsule` — inline misuse, heavy | ContinueReadingView.swift:50 | med | Plain rows in a List (pairs with finding #9) |
| Row-based content in LazyVStack inside parent ScrollView (checklist #4) | ContinueReadingView.swift:18-22 | low | List rows |
| Chevron shown only on non-resumable rows — two row archetypes for the same list | ContinueReadingView.swift:30-56 | low | One archetype; make the whole row open detail and keep the play button |
| Empty state native ContentUnavailableView ✓ | ContinueReadingView.swift:11-16 | — | — |

## Downloads (DownloadsView + DownloadSettingsView)

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| No `.refreshable` on the downloads List (every other main list has it) | DownloadsView.swift:54-81 | low | Add `.refreshable { await viewModel?.refresh() }` |
| "Series" section header states the obvious (all rows are series cards) | DownloadsView.swift:69-71 | low | Drop the header, keep the storage footer |
| Settings reachable only via `ellipsis.circle` → menu → NavigationLink; a gear belongs on the toolbar | DownloadsView.swift:25-29 | low | Dedicated `gearshape` toolbar button; keep Clear All in the ellipsis menu |
| `checkmark.icloud.fill` implies cloud but downloads are local | DownloadsView.swift:144 | low | `checkmark.circle.fill` or `arrow.down.circle.fill` |
| Failed-state `.red` label — semantic, allowed ✓; empty state native ContentUnavailableView ✓; List for row-based screen ✓ | DownloadsView.swift:57-62, 139-142 | — | — |
| DownloadSettingsView: Form, inline pushed title, footers — no findings; cleanest screen in the app | DownloadSettingsView.swift:11-61 | — | — |

## Forum (channels)

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| `.toolbar` attached outside `NavigationStack` — compose + adult menu likely never render (verify on device) | ForumView.swift:47-70 | high | Move `.toolbar` inside, attached to each content branch (or the shared container) |
| `navigationTitle` only on signed-in List branch and signed-out branch — blank bar during loading/error | ForumView.swift:98-116, 128-133 | med | One `.navigationTitle("Forum")` on the container inside the stack |
| `18.circle` SF symbol for "Adult channels" toggle (brief-flagged) | ForumView.swift:64 | med | Drop the icon: `Toggle("Adult channels", isOn:)` in the menu |
| Filter icon (`line.3.horizontal.decrease.circle`) for a settings/toggle menu | ForumView.swift:67 | med | `gearshape` or `eye` (it toggles adult visibility, it doesn't filter the feed) |
| Custom EmptyStateView "No channels" | ForumView.swift:105 | med | `ContentUnavailableView("No channels", systemImage: "bubble.left.and.bubble.right")` |
| `includeAdult` defaults to `true` for new users — adult channels on by default | ForumView.swift:38 | low | Default `false` (safer default; also matches the toggle's purpose) |

## ChannelPostsView

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Sort + Tag pickers share one menu behind the filter icon — sort should use its own semantics (checklist #2: `arrow.up.arrow.down.circle`) | ForumView.swift:216-244 | med | Two toolbar menus: sort menu w/ `arrow.up.arrow.down.circle`, tag menu w/ `line.3.horizontal.decrease.circle` |
| Custom EmptyStateView "No posts yet" | ForumView.swift:284 | med | `ContentUnavailableView("No posts yet", systemImage: "bubble.left")` |
| No pagination — only `page: 0` loads; long channels silently truncate | ForumView.swift:187 | low | Add onAppear load-more like Browse |
| Pushed screen inline title ✓; compose icon `square.and.pencil` ✓ | ForumView.swift:213-214, 247 | — | — |

## PostDetailView + EditPostView

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Tag chips `glassCapsule` inline (non-interactive decorations) | PostDetailView.swift:265-273 | med | `Text("#\(name)").background(.quaternary, in: Capsule())` — no glass |
| Vote colors hardcoded `.yellow` (up) / `.blue` (down) in two places | PostDetailView.swift:279-281, 287 · CommentsView.swift:214, 232 | low | Semantic-ish but inconsistent with app accent; pick `.orange`/`.blue` or tint-based pair, defined once |
| Generic alert title "Error" for failed edit/delete | PostDetailView.swift:186-194 | low | Title per action ("Couldn't save changes" / "Couldn't delete post") |
| Generic nav title "Post" adds nothing; header already shows the real title | PostDetailView.swift:143 | low | Keep (fine for inline) or use the post title truncated — document choice |
| EditPostView sheet: no detents/grabber | PostDetailView.swift:165-169 | med | `.presentationDetents([.large])` + `.presentationDragIndicator(.visible)` |
| EditPostView Cancel discards typed edits without confirmation | PostDetailView.swift:356-358 | low | confirmationDialog when `title`/`content` differ from originals |
| Bottom action bar `glassCapsule` — legitimate floating chrome ✓ | PostDetailView.swift:291-295 | — | — |

## ComposeView

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Compose sheet: no `presentationDetents` (default large is right) and no grabber | ForumView.swift:88-90, 263-265 | med | `.presentationDetents([.large])` + `.presentationDragIndicator(.visible)` |
| Channel picker is a native Form Picker ✓ (brief's feared "compose channel picker" glass misuse doesn't exist); tag chips use non-glass capsule fills ✓ | ComposeView.swift:218-231, 240-256 | — | — |
| Submit-in-toolbar ProgressView swap + `interactiveDismissDisabled` ✓; keyboard toolbar dismiss ✓ | ComposeView.swift:129-153, 165 | — | — |

## MangaDetailView

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Genre/tag chips `glassCapsule` inline (both collapsed scroll and expanded flow) | MangaDetailView.swift:233-239, 170-186 | med | `.background(.quaternary, in: Capsule())`; consider `Layout`+`AnyLayout` instead of the dual presentation |
| Toolbar `ellipsis.circle` Menu wraps a single action ("Add to list") | MangaDetailView.swift:80-91 | low | Direct toolbar button `plus.rectangle.on.rectangle` (HIG: menus for 2+ actions) |
| "No chapters for this group." plain text when scanlator filter empties the list | MangaDetailView.swift:256-259 | low | `ContentUnavailableView("No chapters", systemImage: "book.closed")` |
| Section headers `.headline` ("Details", "Chapters") vs guideline `.title2.bold()` | MangaDetailView.swift:153, 247 | low | `.title2.bold()` per checklist #8 |
| Chapter rows in LazyVStack have no separators or chevron — rows read as dead text | MangaDetailView.swift:307-348 | low | List (gets separators/swipe for downloads later) or add chevron affordance |
| Nav title is empty string while loading — blank nav bar flash | MangaDetailView.swift:40 | low | `.navigationTitle("Manga")` placeholder or hidden-until-loaded |
| Offline banner, continue-reading `glassProminent`, sibling download control, confirmationDialog — all good patterns ✓ | MangaDetailView.swift:66-69, 193-203, 350-355, 96-102 | — | — |

## MangaReaderView (paged + strip)

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Chrome never hides: page slider permanently floats over art; no tap-to-toggle for nav bar + slider | MangaReaderView.swift:84-91 | high | `@State showChrome`; toggle on tap; render slider `if showChrome` |
| `.toolbarBackground(.hidden)` → white toolbar icons directly on page art, unreadable on light pages | MangaReaderView.swift:43 | high | Toggle `.toolbar(showChrome ? .visible : .hidden, for: .navigationBar)` with chrome state (keeps immersive default) |
| `readingDirection` (@AppStorage "ltr") has no UI anywhere — RTL unreachable | MangaReaderView.swift:13 | med | Add LTR/RTL toggle to the mode menu |
| `readerFit` (@AppStorage) has no UI anywhere — Fit/Fill unreachable | MangaReaderView.swift:14 | med | Add Fit/Fill toggle to the mode menu |
| Comments sheet has no detents/grabber | MangaReaderView.swift:66-70 | med | `.presentationDetents([.large])` + grabber (it's a full comment list) |
| Page-number labels in fixed `width: 36` frames — clip with large page counts at big Dynamic Type | MangaReaderView.swift:325, 338 | low | `fixedSize()` + `monospacedDigit()`, or `containerRelativeFrame` |
| Zoom gesture exists in paged mode only; strip mode can't zoom | MangaReaderView.swift:242-249 | low | Document or add magnification to strip rows |
| Paged mode: each page is its own vertical `ScrollView` — vertical micro-scroll inside horizontal paging surprises | MangaReaderView.swift:258-269 | low | Reserve vertical scroll for zoomed state only (`allowsHitTesting`/`scrollDisabled` when `zoomScale == 1`) |
| Page slider `glassCapsule` — legitimate floating chrome ✓; inline `.navigationBarTitleDisplayMode` ✓; tab bar hidden ✓ | MangaReaderView.swift:343, 44, 45 | — | — |

## NovelReaderView

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Paragraph text scrolls under fully transparent nav bar — title/text collision, no chrome toggle | NovelReaderView.swift:38-41 | high | Chrome toggle like manga reader, or restore nav bar background for this screen |
| Typography popover: fixed `width: 300` + `.presentationCompactAdaptation(.popover)` — cramped/fragile on iPhone with Dynamic Type | NovelReaderView.swift:160-162 | med | Sheet with `.presentationDetents([.fraction(0.35)])` on compact, popover only on regular |
| Paragraph comment-count badge `glassCapsule` inline | NovelReaderView.swift:112-121 | med | `.background(.quaternary, in: Capsule())` |
| Whole paragraph is the tap target for comments — accidental opens while reading | NovelReaderView.swift:111 | low | Tap opens chrome/comments only via a dedicated affordance, or require tap on trailing badge |
| `textformat` settings icon ✓; inline title ✓; retry ContentUnavailableView ✓ | NovelReaderView.swift:133, 40, 24-27 | — | — |

## Account (AccountView)

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Stat tiles `glassCapsule` — inline misuse (4 tiles in a grid) | AccountView.swift:110-125 | med | `.background(.quaternary, in: RoundedRectangle(cornerRadius: 16))` or a List section |
| "Manage account" Link row `glassCapsule` — inline row misuse | AccountView.swift:131-143 | med | List row with chevron, or `.buttonStyle(.bordered)` |
| "Premium" badge `glassCapsule` | AccountView.swift:66-71 | low | `.background(.quaternary, in: Capsule())` |
| Sign out is immediate with no confirmation — destructive action on the profile screen | AccountView.swift:148-149 | low | confirmationDialog ("Sign out of atsumaru?") |
| Data loads in `.onAppear` (re-triggers on every reappear without need) instead of `.task` | AccountView.swift:49-54 | low | `.task { … }` |
| Root tab large title ✓; ErrorStateView for profile load ✓ | AccountView.swift:26, 40 | — | — |

## Auth sheet (AuthFlowView, LoginView, ForgotPasswordView, ResetPasswordView)

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| `.presentationDetents([.medium])` — login form + keyboard don't fit; ForgotPassword `Form` push is cramped in medium | AuthFlowView.swift:11 | med | `.presentationDetents([.large])` (keep drag indicator) |
| Username/password fields `glassCapsule` — inline form-field misuse | AuthFlowView.swift:36-56 | med | `.textFieldStyle(.roundedBorder)` or `.background(.quaternary, in: RoundedRectangle(cornerRadius: 12))` |
| ForgotPasswordView keeps default large title inside a sheet — inconsistent with every other sheet's inline title | ForgotPasswordView.swift:56 | low | `.navigationBarTitleDisplayMode(.inline)` |
| ResetPasswordView success message hardcoded `.green` (fails in some color settings; semantic green ok-ish but check) | ForgotPasswordView.swift:82 | low | Keep `.green` only if verified dark-mode legible; else secondary + checkmark icon |
| Nav title "Reset" is vague | ForgotPasswordView.swift:101 | low | `.navigationTitle("Reset password")` |
| Error text `.red` semantic ✓; signup via external URL ✓ | AuthFlowView.swift:59-64, 80-82 | — | — |

## Comments (manga comments sheet + paragraph comments)

| Finding | File:line | Severity | Fix |
|---|---|---|---|
| Empty states are plain `Text("No comments yet")` — not ContentUnavailableView (checklist #5) | CommentsView.swift:66-71 · ParagraphCommentsSheet.swift:41-44, 61-67 | med | `ContentUnavailableView("No comments", systemImage: "bubble.left")` |
| Spoiler reveal button `glassCapsule` inline | CommentsView.swift:183-190 | med | `.background(.quaternary, in: Capsule())` |
| Spoiler hidden content uses `.blur(10).opacity(0.0)` — blur is pointless at opacity 0 (dead code; also fully hidden content still occupies height, which is fine) | CommentsView.swift:178-182 | low | Drop the blur; keep opacity 0 (or keep blur, drop opacity — pick one) |
| Vote colors `.yellow`/`.blue` — same as PostDetailView (fix together) | CommentsView.swift:214, 232 | low | Shared vote-color tokens |
| Composer pill `glassCapsule` — legitimate floating chrome ✓; reply-cancel UI ✓ | CommentsView.swift:113-127, 96-106 | — | — |

---

## Tally

| Severity | Count |
|---|---|
| high | 5 |
| med | 36 |
| low | 52 |

Cross-screen themes for the two implementation passes:
1. **Pass A (chrome & structure):** ForumView toolbar placement, reader chrome auto-hide, sheet detents/grabbers, Browse title, List conversions (history/continue-reading/chapters), dead reader settings.
2. **Pass B (systemization):** delete `EmptyStateView` → `ContentUnavailableView` everywhere, strip `glassCapsule` from ~14 inline sites → `.quaternary` capsule backgrounds, unify poster cells + grid spacing via `PosterGrid`, vote-color tokens, error passthrough in ListDetailView.
