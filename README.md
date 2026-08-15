# Atsumaru for iOS

A native iOS client for [atsu.moe](https://atsu.moe) — read, track, and download manga, manhwa, manhua, and light novels, ad-free.

> **Disclaimer:** This is an **unofficial, third-party** client. It is not affiliated with or endorsed by Atsumaru. All content belongs to its respective owners. This app is intended for **personal use via sideloading** only.

## Features

- **Browse & discover** — home feed rails, full browse grid, search with filters and sorting (genres, tags, types, statuses, ratings)
- **Manga reader** — paged and vertical-strip modes, reading direction, data-saver image variants, reading progress sync
- **Novel reader** — light-novel reading with adjustable typography and paragraph-level comments
- **Offline downloads** — download chapters for offline reading, with storage management
- **Background auto-update** — refresh your library and auto-download new chapters in the background (BGAppRefreshTask / BGProcessingTask)
- **Accounts** — login, signup, OAuth (Google/Discord/AniList/MangaBaka), email verification, password reset, profile & settings management
- **Library & tracking** — bookmarks, reading history, custom lists, continue-reading shelf
- **Community** — chapter/paragraph comments, forum, user profiles, follows, and groups

## Requirements

- iOS 26.0+
- Xcode 26+
- Swift 6

## Build

```bash
brew install xcodegen
xcodegen generate
open Atsumaru.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project Atsumaru.xcodeproj -scheme Atsumaru \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Run tests:

```bash
xcodebuild -project Atsumaru.xcodeproj -scheme Core \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Architecture

- **UI:** SwiftUI with Apple's Liquid Glass design language (`glassEffect`, `GlassEffectContainer`), `@Observable` MVVM
- **Networking:** typed `APIClient` mirroring Atsumaru's Hono RPC API (`https://atsu.moe/api/*`), cookie-session auth persisted in the Keychain
- **Persistence:** SwiftData for the local cache (downloads, reading progress); server is the source of truth
- **Downloads:** background `URLSession` + `BGTaskScheduler` for offline reading and background updates
- **Layout:** `Core/` (SPM package — models, networking, persistence) + `Atsumaru/` (app target — SwiftUI features)

## Dependencies

- [Kingfisher](https://github.com/onevcat/Kingfisher) — image loading & caching
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) — novel & forum rendering
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — project generation

## Legal

This project is provided for personal and educational use. Respect the site's terms of service and the rights of content creators. Do not redistribute downloaded content.
