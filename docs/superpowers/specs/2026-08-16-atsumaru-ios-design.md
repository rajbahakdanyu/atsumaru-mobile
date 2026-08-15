# Atsumaru iOS — Design Spec

**Date:** 2026-08-16
**Status:** Approved

## Goal

A native iOS client for https://atsu.moe (manga/manhwa/manhua + light novels) with browsing, search/filter/sort, offline downloads, background auto-update, accounts, library sync, comments, forum, profiles and groups.

## Constraints & Decisions

- **Relationship:** Unofficial third-party client. Uses atsu.moe's existing web API (`https://atsu.moe/api/*`, cookie-session auth). Cannot change the backend.
- **Distribution:** Personal sideloading only (free/paid dev account). No App Store.
- **Platform:** iOS 26.0+ (enables Liquid Glass). iPhone-first, SwiftUI only.
- **Architecture:** Pure SwiftUI, `@Observable` MVVM + Repository pattern. Single app target + local SPM packages for core logic.
- **Downloads:** In-app offline cache (works for all users). Background auto-update/auto-download via BGTaskScheduler + background URLSession.
- **Dependencies:** Kingfisher (images), MarkdownUI (novels/forum), XcodeGen (project generation). SPM only, no CocoaPods.
- **UI:** Apple Liquid Glass — `glassEffect`, `GlassEffectContainer`, `.glass` button styles, tab bar minimization.
- **Data:** SwiftData for local cache; server is source of truth.

## Feature Scope

- **Core:** Home rails, browse grid, search, filter/sort, manga detail, manga reader (paged + vertical strip), novel reader, downloads, auth.
- **Library & tracking:** bookmarks, history, lists, continue-reading, progress sync, notifications.
- **Community:** comments (chapter + paragraph), forum, profiles, follows, groups.
- **Out of scope v1:** mod tools, premium server-side .cbz jobs (still surface premium state where relevant).

## Key API Facts (verified)

- Base: `https://atsu.moe/api/*`, cookie session (`credentials: include`), form-encoded auth endpoints.
- Search: Typesense-style `/collections/manga/documents/search?q=&query_by=&per_page=&page=&filter_by=` returning `{found, hits:[{document}]}`.
- Home rails: `/api/home2/{popular,topRated,rising,recommended,recentlyUpdated,recentlyAdded,hotUpdates,...}` → `{items:[{id,title,image,smallImage,mediumImage,largeImage,isAdult,type,medium,mbRating,views}]}`.
- Manga page: `/api/manga/page?id=` → `{mangaPage:{...chapters,recommendations,similarManga,relations,genres,tags,synopsis,startReading,...}}`.
- Manga info (lightweight): `/api/manga/info?mangaId=` → `{chapters:[{id,title,number,index,pageCount,scanId}]}`.
- Chapters (paginated): `/api/manga/chapters?id=&page=` → `{chapters:[{id,title,number,index,pageCount,createdAt}]}`.
- Read chapter: `/api/read/chapter?mangaId=&chapterId=` → `{readChapter:{id,title,scanlationMangaId,pages:[{id,image,number,width,height,aspectRatio}]}}`. Page image paths are relative (`/static/pages/...`).
- Novel chapter: `/api/read/novelChapter?mangaId=&chapterId=` (paragraph-based).
- Progress: `read.updateProgress`, `read.syncProgress`.
- Filters: `/api/explore/availableFilters` → `{genres,tags,types,statuses}`.
- Auth: `auth.login`/`auth.signup` (form), `auth.me`, `auth.myPreferences`, `auth.oauth.*` (discord/google/anilist/mangabaka), `auth.verify`, `auth.sendVerification`, `auth.resetPassword.*`.
- User: `user.bookmarksPage`, `user.history`, `user.userMangaLists.*`, `user.follow*`, `user.publicProfile.*`, `user.settings.*`, `user.notificationPreferences`, `notifications.*`.
- Community: `comments.v2.*`, `comments.commentSections.getParagraphCommentSection`, `forum.*`, `groups.*`, `polls.*`.
- Images served same-origin (`atsu.moe/posters/...`, `/static/pages/...`).

## Architecture (modules)

```
Atsumaru/            # app target (XcodeGen project.yml)
  App/               # entry, root TabView, DI (AppEnvironment)
  Core/
    Networking/      # APIClient, endpoints, cookie session
    Models/          # DTOs + domain models
    Persistence/     # SwiftData store, DownloadManager, BackgroundScheduler
    DesignSystem/    # glass components, themes
  Features/          # Home, Browse, MangaDetail, Reader, Novel, Downloads,
                     # Library, Auth, Account, Comments, Forum, Community
```

## Testing

- Swift Testing (`import Testing`) for unit tests (DTO decoding w/ fixtures, query builder, progress merge, storage eviction).
- URLProtocol stubs for API client integration tests (no live network in CI).
- Build verification via `xcodebuild build` + `xcodebuild test` on iPhone simulator.
