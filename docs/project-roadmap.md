# Project roadmap

Phases follow the README roadmap. Status is what the code does on 2026-10-23 (`main` at `ff93a6c`), checked against [features.md](./features.md) and the merged PRs. Feature IDs point to the requirement; the status column says what is real.

Status labels: **Done** (shipped, merged), **Partial** (some of the requirement shipped), **Open** (not started), **Known issue** (shipped, with a documented limit).

Last updated: 2026-10-23.

## Summary

| Phase | Scope | Status |
|---|---|---|
| 0 Foundation | Scaffold, M3 theme, first playback, MPRIS | Done, except CI |
| 1 Offline local player | Scan, library, Now Playing, queue, search, playlists, packaging | In progress: core library, playback (with ReplayGain), search, playlists (create, rename, delete, add, remove, reorder, Favorites, M3U), History, colors from the cover and the AppImage shipped; Flatpak, `.deb` and the schema collapse open |
| 2 More platforms | Windows, macOS, Android, iOS | Open |
| 3 Remote sources | `StorageProvider`, proxy, cache, Subsonic, WebDAV, S3, SFTP, Drive | Open |
| 4 Juicy | Lyrics, waveform, EQ, stats, scrobbling, cross-device sync | Open (a few UI placeholders exist) |

## Shipped history

PRs merged to `main`, 418 commits from 2026-10-18 to 2026-10-22 (PR merge dates in UTC). No tags or releases.

| Date | PRs | Theme |
|---|---|---|
| 2026-10-18 | #1 | Sidebar shell, i18n |
| 2026-10-19 | #2 to #8 | Player core, MPRIS, logging, app directories, settings, library indexer (Rust and lofty), analyzer fix |
| 2026-10-20 | #9 to #20 | Now Playing, library browse, UI polish, songs list throttling, player hardening, cover art, startup logging, navigation history test, scan progress, Makefile, reset-all |
| 2026-10-21 | #21 to #27 | Player performance; library data hardening (accent-aware keys, backfill, id-paged songs, indexer fixes); play next, add to queue and shuffle all; two-phase scan and faster cover thumbnails; project docs; original cover art in Now Playing; library tiles moved to `lib/shared` |
| 2026-10-22 | #28 to #46 | Full-text search; library folders in Settings and startup rescan; schema 5 (plays, play stats, playlists); listen recorder; AppImage; playlists; icons through `AppIcons`; player hardening; settings sections; cover scan timing; schema 6 and new settings; ReplayGain and output device; scan filters, excluded folders, folder watching and opening files; genres and folders; History and Favorites routes; colors from the cover; listen history pages; Favorites, M3U and save the queue |

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
| Folder scanning, tag reading, embedded and folder artwork | Done | IDX-02, IDX-03, IDX-10, META-01, META-03, META-04 | PRs #7, #15, #18. Folder watching (IDX-04), `.nomedia`, size and duration filters (IDX-05) and excluded folders (IDX-13) shipped in PR #41. Open in the same area: error list (IDX-07). |
| Library database and browsing | Partial | LIB-01, LIB-02, LIB-03, LIB-04, LIB-06, LIB-07, LIB-19 | Albums, artists and songs shipped (PRs #10, #13); genres (LIB-04) and folders (LIB-06, LIB-19) shipped in PR #42 (folders: tree or flat list, recursive counts, whole-subtree actions; hidden folders and merging single-child folders still open). Sort keys: songs, albums and artists. Play count not in sort. |
| Now Playing, mini player, queue, shuffle, repeat | Partial | NP-01, NP-02, QUEUE-02 to QUEUE-05, PLAY-12 | Player bar, Now Playing overlay, queue sheet and session restore shipped (PRs #2, #9, #14). Queue history (QUEUE-07) is the History page (tap a play to play that day's songs again). Save the queue as a playlist (QUEUE-06) shipped. Open: hero transition (NP-03), play-after-current-track (QUEUE-10). |
| Full-text search | Done | SEARCH-01 to SEARCH-09 | Songs, albums and artists, accent-insensitive, live from the top bar. Schema v4 with an FTS5 index. Typo correction (SEARCH-04), search history in `search_history.json` (SEARCH-05), field syntax (SEARCH-06), `Ctrl+F` and `/` (SEARCH-07), field picker (SEARCH-08) and filter boxes on album, artist, genre, playlist, Favorites and queue (SEARCH-09) shipped on feat/search-complete. Open: search over lyrics (SEARCH-08). Limits are listed in features.md, section 6. |
| Playlists (incl. M3U) | Done | PL-01 to PL-05 | PL-01 and PL-02 shipped (PR #33): create, rename, delete, cover collage, add from every queue menu and from Now Playing, remove, drag to reorder. Favorites (PL-03: hearts in Now Playing, player bar and the song menu, `/favorites`), M3U import and export (PL-04, PL-05) shipped (PR #46). Open: reading M3U files during scans, syncing an imported M3U when its file changes. |
| Gapless and ReplayGain | Partial | PLAY-06, PLAY-07 | Gapless: mpv `gapless-audio=weak` is set; not marked done in features.md. ReplayGain: done in PR #40 (off, track, album, auto; preamp; clipping protection; output device choice in Settings > Advanced). |
| Dynamic color from album art | Done | UI-03 | "Colors from the cover" switch: the playing cover's seed tints the whole app and Now Playing gets a gradient of its colors. Colors come from one Rust function, are worked out by the scan's cover pass (or at once for the playing track) and stored per cover. |
| Packaging: AppImage, Flatpak, `.deb` | Partial | PKG-01 to PKG-03 | AppImage done (PR #32, `make appimage`, x86_64). No Flatpak or `.deb` files exist. The AppImage ships a `.desktop` file with audio MIME types (SYS-07). |
| Collapse schema history into v1 before first release | **Open** | PKG-08 | Schema is v6 with migration steps. Required before the first release; see [system-architecture.md](./system-architecture.md#7-library-database-schema). |

Also shipped in Phase 1 and not listed in the README: responsive shell (UI-05), reduced motion (UI-06), custom title bar choice (UI-07), i18n en and vi (UI-10), single instance on Release and Profile builds (SYS-06), desktop accent color (UI-04), scan progress (IDX-10).

Partial items: keyboard shortcuts (SYS-03: Space, ←/→, Ctrl+S, Ctrl+R only), accessibility (UI-11), reset (SET-05: library rescan and reset via Makefile only), logs (SET-06: written to disk, no in-app viewer or export).

### Phase 1 next priorities

Ordered by what blocks a first usable release. IDs are from [features.md](./features.md).

| Order | Item | IDs | Why here |
|---|---|---|---|
| 1 | Playlists: create, rename, delete, add, reorder | PL-01, PL-02 | Done (PR #33) on the v5 tables; QUEUE-06 (save the queue as a playlist) done in PR #46 with `createPlaylist(paths:)`. |
| 2 | Listen recorder (no UI yet) | STAT-01, STAT-10 | Done (PR #31). P0. History cannot be backfilled, so recording starts before the history UI. Last.fm rule (> 30 s, listened ≥ min(50 %, 4 min)); append-only `plays` rows in the library DB. |
| 3 | Root removal and folder edits in Settings | IDX-01 (remainder) | Done (PR #29). Add, change and remove in Settings → Library; onboarding only on first run. |
| 4 | Startup rescan option | IDX-06 | Done (PR #29). On by default, switch in Settings, quiet unless something changed. A snackbar with a Settings action warns once per launch about missing music folders, whether or not the rescan is on. |
| 5 | AppImage package | PKG-01 | Done (PR #32). P0. libmpv is bundled by the AppImage recipe. |
| 6 | CI for `flutter analyze`, `flutter test`, `cargo test --locked` | Phase 0 CI item | Blocks trustworthy releases. Needs a workflow file. |
| 7 | ReplayGain, folder watching | PLAY-07, IDX-04 | Done. ReplayGain (PLAY-07): PR #40. Folder watching (IDX-04): PR #41. |
| 8 | History UI: timeline, most played by range, per-track history | STAT-06, STAT-07, STAT-08, QUEUE-07 | Done (PR #45). P1. Reads the recorder's rows; per-song play counts on song rows and editing play times are still open (STAT-08). |
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
| Listening stats, scrobbling (Last.fm, ListenBrainz, Discord) | STAT-03, EXT-01 to EXT-03 | Listen recording (STAT-01, STAT-10) and the history UI (STAT-06 to STAT-08) are built; STAT-02 and STAT-11 are Phase 1 and not built |
| Sync playlists and settings across devices | SET-04 | Not started |
| Backup and restore | SET-03 | Not started |

Premium candidates for these items are listed in [project-overview-pdr.md](./project-overview-pdr.md#open-questions) and [features.md section 20](./features.md).

## Open decisions

These affect the roadmap; the owner has not decided them (features.md, open questions):

1. Final premium list, and whether the free tier limits remote sources.
2. Whether the tag editor (META-08) moves into Phase 1.
3. Whether 1.0 means Phase 1 on Linux only, or also Phase 3.
4. Whether Material 2 styling (UI-12) is offered.
