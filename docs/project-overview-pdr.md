# Project overview and PDR

Kanaru is a Material 3 music player for GNU/Linux first, built with Flutter. It plays and manages a local library offline, with no account and no telemetry. Remote sources and premium features come later.

Status date: 2026-10-21. Pre-release (`0.1.0+1`, no tags, no packages, no CI). See [Current status](#current-status).

## Vision

One player for a music library, wherever it lives. The local library comes first; the same model later covers streaming and cloud sources without changing how playback or the library UI work.

## Priorities

Ordered. A later item does not start while an earlier one blocks the first usable release.

| # | Priority | Meaning in practice |
|---|---|---|
| 1 | **GNU/Linux first** | Linux desktop is the only target until Phase 2. Linux-only code (MPRIS, GTK runner) is not a sign of a portability problem. |
| 2 | **Offline local player first** | A complete offline player (scan, browse, play, queue, restore) ships before any streaming, remote or cloud work. |
| 3 | **Open source, premium extras** | All features needed to use Kanaru as an offline player are free. Premium is a proposal for extra features only ([features.md section 20](./features.md)). |

## Target users

| User | Need | Served by |
|---|---|---|
| Listener with a local music folder on Linux | Fast library, gapless playback, system media keys, no account | Phase 1 |
| Self-hoster with a Navidrome, Nextcloud or S3 bucket | One library for local and remote music | Phase 3 |
| Packager and contributor | Clear build, docs, tests and a small set of conventions | [development.md](./development.md), [code-standards.md](./code-standards.md) |

Non-goals now: streaming from commercial services, podcasts, video, network sharing and DLNA ([features.md section 21](./features.md)).

## Functional requirements

Requirements are defined in [features.md](./features.md) with stable IDs, priority (P0 to P3) and phase. This page does not repeat the table. Areas:

| Area | features.md section | Core IDs (examples) |
|---|---|---|
| Playback engine | 1 | PLAY-01 to PLAY-04, PLAY-12, PLAY-13 |
| Queue and modes | 2 | QUEUE-01 to QUEUE-05 |
| Scanning and index | 3 | IDX-01 to IDX-05, IDX-06, IDX-09, IDX-13 |
| Metadata and artwork | 4 | META-01, META-03, META-04 |
| Library browsing | 5 | LIB-01 to LIB-03, LIB-07 |
| Search | 6 | SEARCH-01 to SEARCH-03 |
| Playlists | 7 | PL-01 to PL-05 |
| Now Playing and player bar | 8 | NP-01 to NP-03 |
| Lyrics | 9 | LYR-01 to LYR-04 (Phase 4) |
| Theme and UI | 10 | UI-01 to UI-07, UI-10, UI-11 |
| System integration | 11 | SYS-01 to SYS-08, SYS-15 |
| External services | 12 | EXT-01 to EXT-04 (Phase 3 and 4) |
| Remote sources | 13 | SRC-01 to SRC-10 (Phase 3) |
| Cache and offline | 14 | CACHE-01 to CACHE-06 (Phase 3) |
| Statistics | 15 | STAT-01, STAT-02, STAT-06 to STAT-08, STAT-10, STAT-11 |
| Settings and data | 16 | SET-01, SET-02, SET-05, SET-06 |
| Privacy | 17 | PRIV-01 to PRIV-04 |
| Packaging | 18 | PKG-01 to PKG-08 |

Status of each ID is tracked in [project-roadmap.md](./project-roadmap.md), not here.

## Non-functional requirements

From [features.md section 19](./features.md). Targets, not guarantees: measured numbers are not recorded in the repo.

| ID | Requirement | Target | How it is checked today |
|---|---|---|---|
| NFR-01 | Startup to library visible | < 1.5 s, 20k tracks, cold SSD | Not measured in CI |
| NFR-02 | Memory during playback | < 200 MB, 20k tracks | Not measured |
| NFR-03 | Large library | Browse, search and scroll at 60 fps, 100k tracks | Benchmarks gated by `KANARU_BENCH=1` (no stored reference numbers) |
| NFR-04 | Package size | AppImage < 60 MB | No package yet |
| NFR-05 | Stability | Bad files, bad tags, lost network or dead remote do not crash | Error handling is per file and per batch; see [code-standards.md](./code-standards.md#error-handling) |
| NFR-06 | Data integrity | Migrations tested; playlists and ratings survive upgrades | Migration tests exist; playlists and ratings not built |
| NFR-07 | Testing | Unit tests for core, widget tests for main flows | About 1,064 Dart tests and 53 Rust tests (scout count) |

Privacy and security constraints (PRIV-01 to PRIV-04) apply to every release: no telemetry, no account, network features behind explicit switches, credentials only in the system keyring (planned).

## Technical constraints

| Constraint | Value | Source |
|---|---|---|
| Dart SDK | `^3.13.3` | `pubspec.yaml` |
| Flutter | `>= 3.47` | [development.md](./development.md#what-you-need) |
| Rust | `1.89`+ | `rust/Cargo.toml` |
| libmpv | `>= 0.36` | [development.md](./development.md#what-you-need) |
| GTK | `>= 3.24` | same |
| Database | SQLite via drift, `schemaVersion = 4` | [system-architecture.md](./system-architecture.md#7-library-database-schema) |
| License | GPL-3.0-or-later | [LICENSE](../LICENSE) |

## Current status

Status on 2026-10-21, with the search work on `feat/search`. Commit and PR counts are from `1cd20bc`: 208 commits, PRs #1 to #22, between 2026-10-18 and 2026-10-21.

| Area | State |
|---|---|
| Shell, theme (M3), i18n (en, vi), desktop title bar | Shipped |
| Playback (media_kit, queue, shuffle, repeat, session restore) | Shipped; gapless configured but not verified (PLAY-06); ReplayGain and output device not done |
| MPRIS (own D-Bus implementation) | Shipped |
| Folder scan, tags (Rust, lofty), embedded and folder artwork | Shipped, with startup rescan and root removal; file watching not done |
| Library browse: Songs, Albums, Artists, Genres, Folders | Shipped |
| Library browse: Favorites, History | Not started (placeholder screens) |
| Now Playing overlay and queue sheet | Shipped; hero transition not built |
| Search | Shipped: songs, albums and artists, live from the top bar; typo tolerance not done (SEARCH-04) |
| Playlists | Done: create, rename, delete, add, remove, reorder (PL-01, PL-02), Favorites (PL-03), M3U import and export (PL-04, PL-05), save the queue (QUEUE-06) |
| Settings | Shipped in part (library folders, rescan, appearance, about) |
| Packaging (AppImage, Flatpak, deb, rpm) | Not started |
| CI | Not started (no `.github/` workflows) |
| Remote sources, cache, licensing | Not started |

Roadmap and per-ID status: [project-roadmap.md](./project-roadmap.md).

## PDR: first usable release

Scope of the first release, derived from the P0 items of Phase 1 (features.md).

### Goals

- A Linux user can install one package, point Kanaru at a music folder, and play, browse and search the library offline.
- Playback survives a restart; media keys work through MPRIS.
- Nothing leaves the machine.

### Requirements still open

| Requirement | ID | Priority | State |
|---|---|---|---|
| Playlists: create, edit, delete, add and reorder | PL-01, PL-02 | P0 | Done |
| AppImage package | PKG-01 | P0 | Not started |
| Collapse DB schema history to v1 before release | PKG-08 | P0 | Not started |
| Startup rescan option | IDX-06 | P1 | Done |
| Folder watching | IDX-04 | P1 | Done (switch in Settings, off by default) |
| Root removal and folder edits in Settings | IDX-01 (remainder) | P0 | Done |
| ReplayGain | PLAY-07 | P1 | Not started |
| Dynamic color from artwork | UI-03 | P1 | Done |
| Flatpak and deb/rpm | PKG-02, PKG-03 | P1 | Not started |
| CI for analyze, test and cargo test | Phase 0 item | — | Not started |

### Acceptance criteria (proposed)

- `make check` (analyze, Dart tests, Rust tests) passes on a clean checkout.
- A fresh install reaches the folder picker; a second start opens the library with no rescan needed.
- A library of 20,000 tracks scans and browses without UI freezes (NFR-01 and NFR-03 measured, numbers recorded in the release notes).
- Migration to the first release schema is a single step (`schemaVersion = 1`).
- AppImage runs on a current Ubuntu LTS and Fedora without installing libmpv.
- No network calls on a fresh install with no network features enabled.

### Dependencies and risks

| Item | Risk | Mitigation |
|---|---|---|
| Wayland window focus (SYS-15) | Second launch and `Raise` do not bring the window forward on niri | Known limitation; document it; check GNOME and KDE |
| libmpv packaging | AppImage must bundle libmpv | PKG-01 scope |
| Network and FUSE mounts | Not supported; the walk times out instead of hanging | Documented in features.md section 3 |
| Schema history | Migration code is kept only for dev machines | Collapse before release (PKG-08) |

## Open questions

Decisions the owner has not made (features.md, section "Câu hỏi mở"):

1. What is the final premium list? Does the free tier limit remote source count or source type?
2. Should the tag editor (META-08) move into Phase 1?
3. What must 1.0 contain: Phase 1 on Linux only, or also Phase 3 (remote sources)?
4. Will Material 2 styling (UI-12) be offered, or Material 3 only?

## Version history

| Date | Change |
|---|---|
| 2026-10-21 | Initial overview and PDR. Status snapshot at HEAD `1cd20bc`. |
| 2026-10-21 | Search shipped (SEARCH-01 to SEARCH-03); schema v4 with the FTS5 index. |
