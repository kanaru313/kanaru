# Codebase summary

Map of the Kanaru repository: where things live, what each module does, and what is generated. For layering rules see [code-standards.md](./code-standards.md); for runtime design see [system-architecture.md](./system-architecture.md).

Snapshot: 2026-10-21, HEAD `1cd20bc`. 208 commits, PRs #1–#22, no tags. Version `0.1.0+1` (`pubspec.yaml`, `rust/Cargo.toml`). License GPL-3.0-or-later ([LICENSE](../LICENSE)).

Regenerate the compaction with `repomix --style xml -o repomix-output.xml` (see [Compaction](#compaction)); `repomix-output.xml` is not gitignored.

## Entry points

| Entry | File | Role |
|---|---|---|
| Dart `main` | [lib/main.dart](../lib/main.dart) | Bootstrap: logging, media engine, settings, window, library, provider overrides, MPRIS |
| App widget | [lib/app/app.dart](../lib/app/app.dart) | `KanaruApp`: `MaterialApp.router`, theme, l10n |
| Router | [lib/app/router.dart](../lib/app/router.dart) | `routerProvider`, all route paths |
| Linux runner | [linux/runner/my_application.cc](../linux/runner/my_application.cc) | GTK application, single-instance flags, window size |
| Rust API | [rust/src/api/tags.rs](../rust/src/api/tags.rs) | `read_tags_batch`, `read_original_cover` (bridged to Dart) |
| Makefile | [Makefile](../Makefile) | `make` lists targets: run, build, check, gen, reset-* |

## Directory map

### Dart: `lib/`

Sizes are scout counts: files / lines, generated files included where noted.

| Path | Files / lines | Purpose |
|---|---|---|
| `lib/main.dart` | 1 / 85 | Startup sequence, provider overrides |
| `lib/app/` | 17 / 1,601 | Shell, router, theme, window integration, navigation history |
| `lib/app/shell/` | | `app_shell.dart` (layout), `top_bar.dart`, `navigation_history.dart`, `app_destination.dart`, `sidebar/`, `window/` |
| `lib/core/database/` | 16 / 4,575 | drift `LibraryDatabase`, tables, browse/paging queries, text keys, key backfill |
| `lib/core/indexer/` | 15 / 1,464 | Folder walk, tag reading via Rust, diff, scan orchestration, covers |
| `lib/core/logging/` | 9 / 1,106 | Rotating file logger, redaction, session header, error folding |
| `lib/core/media_controls/` | 8 / 790 | Own MPRIS 2.2 server on D-Bus (`mpris/`) |
| `lib/core/paths/` | 1 / 62 | XDG directory resolution |
| `lib/core/player/` | 19 / 2,211 | `PlayerService`, `PlayQueue`, `MediaKitBackend`, session persistence (`session/`) |
| `lib/core/settings/` | 6 / 623 | `settings.json` codec, file I/O, `SettingsNotifier`, applied appearance |
| `lib/features/home/` | 1 / 31 | Placeholder screen |
| `lib/features/library/` | 48 / 3,322 | Songs, Albums, Artists, onboarding, library state machine, sort controls |
| `lib/features/player/` | 28 / 3,300 | `PlayerBar`, Now Playing overlay, queue sheet, seek bar, shortcuts, open-media |
| `lib/features/search/` | 1 / 37 | Placeholder (no query logic yet) |
| `lib/features/settings/` | 10 / 943 | Settings screen sections and setting widgets |
| `lib/shared/` | 6 / 385 | `format_duration.dart`, `widgets/` (CoverArt, EmptyState, PageScaffold, ScanProgress, MinBusyBuilder) |
| `lib/l10n/` | ARB + generated | `app_en.arb` (template), `app_vi.arb`; `app_localizations*.dart` is generated |

Key files by area:

| Area | Files |
|---|---|
| Playback | `core/player/player_service.dart`, `play_queue.dart`, `media_kit_backend.dart`, `mpv_playlist_tracker.dart`, `unavailable_audio_backend.dart` |
| Session restore | `core/player/session/playback_session_file.dart`, `playback_session_saver.dart`, `playback_session_codec.dart` |
| Indexing | `core/indexer/library_indexer.dart`, `walk_audio_files.dart`, `scan_diff.dart`, `tracks_from_tags.dart`, `rust_tag_reader.dart` |
| Library DB | `core/database/library_database.dart`, `library_tables.dart`, `library_browse_queries.dart`, `library_song_paging.dart`, `library_keys_provider.dart`, `throttled_tracks_query.dart` |
| Startup DB | `core/database/library_startup.dart` |
| MPRIS | `core/media_controls/mpris/mpris_media_controls.dart`, `mpris_method_handler.dart`, `mpris_properties.dart` |
| Browse UI | `features/library/library_browse_body.dart` (state machine), `songs/song_row_cache.dart`, `albums/album_screen.dart`, `artists/artist_screen.dart` |
| Now Playing | `features/player/now_playing/now_playing_overlay.dart`, `now_playing_auto_hide.dart`, `now_playing_tabs.dart` |
| Settings | `core/settings/settings_provider.dart`, `settings_codec.dart`, `settings_file.dart` |
| Logging | `core/logging/app_logging.dart`, `rotating_log_file.dart`, `log_redaction.dart` |

### Rust: `rust/`

| Path | Files / lines | Purpose |
|---|---|---|
| `rust/src/api/` | 2 / 126 | Public bridged API (`tags.rs`) |
| `rust/src/tag_reader.rs` | | Per-file read via lofty; `PERMANENT_ERROR_PREFIX` |
| `rust/src/tag_mapping.rs` | | lofty tags to `TrackTags` |
| `rust/src/tag_batch.rs` | | Batch read on a rayon pool |
| `rust/src/cover_art.rs`, `cover_thumbnail.rs`, `cover_cache.rs` | | Embedded and sidecar art, 512 px JPEG thumbnails, blake3 cache keys |
| `rust/src/frb_generated.rs` | 763 | **Generated** by flutter_rust_bridge |
| `rust/Cargo.toml` | | crate `rust_lib_kanaru`, rust 1.89, deps pinned (see [code-standards.md](./code-standards.md#rust)) |

Total Rust (`rust/src`): 10 files, 1,751 lines, including the generated bridge.

### Other top-level paths

| Path | Purpose |
|---|---|
| `test/` | Dart tests; 117 `*_test.dart` files under `core/`, `features/`, `app/`, `shared/`, `drift/` |
| `test/drift/library_db/generated/` | **Generated** schema test code for v1–v3 |
| `drift_schemas/library_db/` | drift schema snapshots `drift_schema_v1..v3.json` (generated by `make-migrations`) |
| `rust_builder/` | Vendored cargokit glue that builds the Rust crate inside Flutter builds |
| `linux/` | GTK runner (`CMakeLists.txt`, `runner/`, `flutter/`) |
| `tool/` | `generate_text_key_tables.py` (generator for `text_key_tables.dart`), `dart-mcp.sh` (MCP launcher) |
| `flake.nix`, `flutter_rust_bridge.yaml` | Nix dev shell; FRB codegen config (`rust_input` `crate::api`, `dart_output` `lib/src/rust`) |
| `.mcp.json` | Registers the Dart MCP server |
| `docs/` | This documentation set |
| `plans/` | Local planning and reports (gitignored) |

## Size stats

| Module | Files | Lines |
|---|---|---|
| `lib/` (excludes `*.g.dart`, `lib/src/rust/`, `lib/l10n/`; includes the two generated files `library_database.steps.dart` and `text_key_tables.dart`) | 186 | 20,535 |
| `rust/src/` | 10 | 1,751 |
| `linux/` | 10 | 570 |
| `test/` | 129 | 26,864 |

Largest non-generated Dart files: `features/settings/full_or_compact_control.dart` (302), `core/indexer/library_indexer.dart` (443), `core/player/media_kit_backend.dart` (296), `core/database/library_database.dart` (231). Generated and large: `core/database/text_key_tables.dart` (1,963, generated), `core/database/library_database.steps.dart` (671, generated).

Files over the 200-line guideline in [CLAUDE.md](../CLAUDE.md) are candidates for splitting; the scout list is `full_or_compact_control` (302), `queue_sheet_host` (234), `seek_gesture_area` (225), `onboarding_screen` (205).

## Generated code

Never edit by hand. Regenerate with the command shown.

| Output | Generator | Command |
|---|---|---|
| `*.g.dart` (drift, e.g. `library_database.g.dart`) | build_runner / drift_dev | `make gen` |
| `lib/core/database/library_database.steps.dart` | drift_dev | `make migrations` (after bumping `schemaVersion`) |
| `drift_schemas/library_db/*.json` | drift_dev | `make migrations` |
| `test/drift/library_db/generated/` | drift_dev | `make migrations` |
| `lib/src/rust/` | flutter_rust_bridge_codegen | `make gen-rust` |
| `rust/src/frb_generated.rs` | flutter_rust_bridge_codegen | `make gen-rust` |
| `lib/core/database/text_key_tables.dart` | `tool/generate_text_key_tables.py` | run the script, then `dart format` (see [development.md](./development.md#library-version-constants)) |
| `lib/l10n/app_localizations*.dart` | Flutter gen-l10n (from `l10n.yaml`) | `flutter gen-l10n` / build |

The step file is rewritten by `make-migrations`; the `fromXToY` wiring lives in `LibraryDatabase.migration` ([library_database.dart](../lib/core/database/library_database.dart)).

## Tests

| Layout | Content |
|---|---|
| `test/core/player/` | Queue, backend, session (`session/`), fakes (`fake_audio_backend.dart`) |
| `test/core/database/` | Browse queries, paging, keys, backfill, migrations; benchmarks gated by `KANARU_BENCH=1` |
| `test/core/indexer/` | Walk, diff, scan orchestration; `fake_tag_reader.dart`, `scripted_indexer.dart` |
| `test/core/media_controls/` | MPRIS with an in-process D-Bus harness |
| `test/core/logging/`, `settings/`, `paths/` | Unit tests |
| `test/drift/library_db/` | `migration_test.dart` against generated schemas |
| `test/features/library/` | Browse UI; `library_test_harness.dart` (`LibraryHarness`, in-memory DB) |
| `test/features/player/` | Player bar, Now Playing layout and auto-hide, volume popup |
| `test/features/settings/` | Settings widgets |
| `test/app/`, `test/shared/` | Router, shell, shared widgets |
| `rust/tests/`, `#[cfg(test)]` | 43 integration and 10 unit tests (format fixtures) |

Counts are from the scout snapshot (about 1,064 Dart tests). Commands and helper details: [development.md](./development.md#tests--lints) and [code-standards.md](./code-standards.md#testing).

## Compaction

```bash
repomix --style xml -o repomix-output.xml \
  --ignore "**/*.g.dart,lib/src/rust/**,rust_builder/**,drift_schemas/**,test/drift/library_db/generated/**,lib/core/database/text_key_tables.dart,**/*.freezed.dart,docs/**,plans/**,linux/flutter/**,pubspec.lock"
```

Output for the 2026-10-21 snapshot: 356 files, about 402k tokens. The compaction is a local artifact; do not commit it.
