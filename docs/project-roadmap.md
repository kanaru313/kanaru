# Project roadmap

Phases follow the README roadmap. Status is what the code does on 2026-10-21 (`main` plus the `feat/search` branch), checked against [features.md](./features.md) and the merged PRs. Feature IDs point to the requirement; the status column says what is real.

Status labels: **Done** (shipped, merged), **Partial** (some of the requirement shipped), **Open** (not started), **Known issue** (shipped, with a documented limit).

Last updated: 2026-10-21.

## Summary

| Phase | Scope | Status |
|---|---|---|
| 0 Foundation | Scaffold, M3 theme, first playback, MPRIS | Done, except CI |
| 1 Offline local player | Scan, library, Now Playing, queue, search, playlists, packaging | In progress: core library, playback and search shipped; playlists, packaging open |
| 2 More platforms | Windows, macOS, Android, iOS | Open |
| 3 Remote sources | `StorageProvider`, proxy, cache, Subsonic, WebDAV, S3, SFTP, Drive | Open |
| 4 Juicy | Lyrics, waveform, EQ, stats, scrobbling, cross-device sync | Open (a few UI placeholders exist) |

## Shipped history

PRs merged to `main`, 208 commits from 2026-10-18 to 2026-10-21. No tags or releases.

| Date | PRs | Theme |
|---|---|---|
| 2026-10-18 | #1 | Sidebar shell, i18n |
| 2026-10-19 | #2 to #8 | Player core, MPRIS, logging, app directories, settings, library indexer (Rust and lofty), analyzer fix |
| 2026-10-20 | #9 to #20 | Now Playing, library browse, UI polish, songs list throttling, player hardening, cover art, startup logging, navigation history test, scan progress, Makefile, reset-all |
| 2026-10-21 | #21, #22 | Player performance; library data hardening (accent-aware keys, backfill, id-paged songs, indexer fixes) |

## Phase 0: Foundation (Linux)

| Item | Status | Features | Notes |
|---|---|---|---|
| Project scaffold, M3 theme | Done | UI-01, UI-02 | PR #1. Light, dark and system theme apply without restart. |
| Play a local file with media_kit | Done | PLAY-01, PLAY-02, PLAY-03 | PR #2. |
| MPRIS integration | Done | SYS-01 | PR #3. Own D-Bus implementation. Media keys reach it only through the desktop (SYS-02). |
| CI | **Open** | — | No `.github/` workflows exist. Quality gates run locally through `make check`. |

## Phase 1: Offline local player (Linux)

| Item | Status | Features | Notes |
|---|---|---|---|
| Folder scanning, tag reading, embedded and folder artwork | Done | IDX-02, IDX-03, IDX-10, META-01, META-03, META-04 | PRs #7, #15, #18. Open in the same area: file watching (IDX-04), error list (IDX-07), `.nomedia` and duration filters (IDX-05 partial). |
| Library database and browsing | Partial | LIB-01, LIB-02, LIB-03, LIB-07 | Albums, artists and songs shipped (PRs #10, #13). Genres (LIB-04) and folders (LIB-06) are empty placeholders. Sort keys: songs, albums and artists. Play count not in sort. |
| Now Playing, mini player, queue, shuffle, repeat | Partial | NP-01, NP-02, QUEUE-02 to QUEUE-05, PLAY-12 | Player bar, Now Playing overlay, queue sheet and session restore shipped (PRs #2, #9, #14). Open: hero transition (NP-03), queue history (QUEUE-07), play-after-current-track (QUEUE-10), playlist from queue (QUEUE-06). |
| Full-text search | Done | SEARCH-01 to SEARCH-03 | Songs, albums and artists, accent-insensitive, live from the top bar. Schema v4 with an FTS5 index. Limits are listed in features.md, section 6. Typo tolerance is SEARCH-04 (P2). |
| Playlists (incl. M3U) | **Open** | PL-01 to PL-05 | Sidebar playlist section is a placeholder. |
| Gapless and ReplayGain | Partial | PLAY-06, PLAY-07 | Gapless: mpv `gapless-audio=weak` is set; not marked done in features.md. ReplayGain: not started. |
| Dynamic color from album art | **Open** | UI-03 | Theme uses GTK accent and a fallback seed. Artwork-based color not built. |
| Packaging: AppImage, Flatpak, `.deb` | **Open** | PKG-01 to PKG-03 | No packaging files exist. No `.desktop` file (SYS-07). |
| Collapse schema history into v1 before first release | **Open** | PKG-08 | Schema is v5 with migration steps. Required before the first release; see [system-architecture.md](./system-architecture.md#7-library-database-schema). |

Also shipped in Phase 1 and not listed in the README: responsive shell (UI-05), reduced motion (UI-06), custom title bar choice (UI-07), i18n en and vi (UI-10), single instance on Release and Profile builds (SYS-06), desktop accent color (UI-04), scan progress (IDX-10).

Partial items: keyboard shortcuts (SYS-03: Space, ←/→, Ctrl+S, Ctrl+R only), accessibility (UI-11), reset (SET-05: library rescan and reset via Makefile only), logs (SET-06: written to disk, no in-app viewer or export).

### Phase 1 next priorities

Ordered by what blocks a first usable release. IDs are from [features.md](./features.md).

| Order | Item | IDs | Why here |
|---|---|---|---|
| 1 | Playlists: create, rename, delete, add, reorder | PL-01, PL-02 | P0. Needs new tables; ties in with QUEUE-06. |
| 2 | Listen recorder (no UI yet) | STAT-01, STAT-10 | P0. History cannot be backfilled, so recording starts before the history UI. Last.fm rule (> 30 s, listened ≥ min(50 %, 4 min)); append-only `plays` rows in the library DB. |
| 3 | Root removal and folder edits in Settings | IDX-01 (remainder) | Done (feat/library-folders). Add, change and remove in Settings → Library; onboarding only on first run. |
| 4 | Startup rescan option | IDX-06 | Done (feat/library-folders). On by default, switch in Settings, quiet unless something changed. |
| 5 | AppImage package | PKG-01 | P0. Needs libmpv bundled; the recipe does not exist yet. |
| 6 | CI for `flutter analyze`, `flutter test`, `cargo test --locked` | Phase 0 CI item | Blocks trustworthy releases. Needs a workflow file. |
| 7 | ReplayGain, folder watching | PLAY-07, IDX-04 | P1, larger changes. |
| 8 | History UI: timeline, most played by range, per-track history | STAT-06, STAT-07, STAT-08, QUEUE-07 | P1. Reads the recorder's rows. |
| 9 | Collapse schema history to v1 | PKG-08 | Do this right before the first release, then write migrations only from then on. |

Pick one item at a time; each should land as one PR from its own branch.

## Phase 2: More platforms

All **Open**.

| Item | Features |
|---|---|
| Windows: SMTC, taskbar controls, installer and portable build | SYS-10, PKG-06 |
| macOS: Now Playing info, media keys, Dock menu, signed `.dmg` | SYS-11, PKG-06 |
| Android: background playback, media style notification, Android Auto (P3) | SYS-12, PKG-07 |
| iOS: background playback, Control Center | SYS-13, PKG-07 |

`media_controls` is Linux-only today (`Platform.isLinux` in `lib/main.dart`); platform code for other OS is not started.

## Phase 3: Remote sources and streaming

All **Open**.

| Item | Features |
|---|---|
| `StorageProvider` interface, local HTTP proxy, disk cache | SRC-01, CACHE-01 |
| Source management and connection test | SRC-02 |
| Unified library across sources | SRC-03 |
| Subsonic and OpenSubsonic (Navidrome) | SRC-04, EXT-04 |
| WebDAV | SRC-05 |
| S3-compatible | SRC-06 |
| SFTP | SRC-07 |
| Google Drive | SRC-08 |
| Remote tag reading and incremental rescans | SRC-09, SRC-10 |
| Download for offline, offline indicators, prefetch, cache management | CACHE-02 to CACHE-06 |

Prerequisites from the architecture: credentials in the system keyring (PRIV-04), and every network feature behind its own switch (PRIV-03). See [system-architecture.md](./system-architecture.md#8-planned-remote-sources-and-licensing).

## Phase 4: Juicy

All **Open**, except placeholders.

| Item | Features | Current state |
|---|---|---|
| Lyrics: `.lrc`, embedded, LRCLIB, synced view | LYR-01 to LYR-04 | Lyrics button is a placeholder in Now Playing |
| Waveform seekbar, visualizer, transitions | NP-05, NP-06 | Seek bar exists; no waveform |
| Equalizer, crossfade, sleep timer, volume boost, speed and pitch | PLAY-05, PLAY-08, PLAY-09, PLAY-14, PLAY-15 | Not started |
| Listening stats, scrobbling (Last.fm, ListenBrainz, Discord) | STAT-03, EXT-01 to EXT-03 | Listen recording and history UI (STAT-01, STAT-02, STAT-06 to STAT-08, STAT-10, STAT-11) are Phase 1 and not built |
| Sync playlists and settings across devices | SET-04 | Not started |
| Backup and restore | SET-03 | Not started |

Premium candidates for these items are listed in [project-overview-pdr.md](./project-overview-pdr.md#open-questions) and [features.md section 20](./features.md).

## Open decisions

These affect the roadmap; the owner has not decided them (features.md, open questions):

1. Final premium list, and whether the free tier limits remote sources.
2. Whether the tag editor (META-08) moves into Phase 1.
3. Whether 1.0 means Phase 1 on Linux only, or also Phase 3.
4. Whether Material 2 styling (UI-12) is offered.
