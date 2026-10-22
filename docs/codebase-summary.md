# Codebase summary

Map of the Kanaru repository: where things live, what each module does, and what is generated. For layering rules see [code-standards.md](./code-standards.md); for runtime design see [system-architecture.md](./system-architecture.md).

Snapshot: 2026-10-21, `feat/search` on `main` (`8bb29d0`). Commit and PR counts are from `1cd20bc`: 208 commits, PRs #1–#22, no tags. Version `0.1.0+1` (`pubspec.yaml`, `rust/Cargo.toml`). License GPL-3.0-or-later ([LICENSE](../LICENSE)).

Regenerate the compaction with `repomix --style xml -o repomix-output.xml` (see [Compaction](#compaction)); `repomix-output.xml` is not gitignored.

## Entry points

| Entry | File | Role |
|---|---|---|
| Dart `main` | [lib/main.dart](../lib/main.dart) | Bootstrap: logging, media engine, settings, window, library, provider overrides, MPRIS |
| App widget | [lib/app/app.dart](../lib/app/app.dart) | `KanaruApp`: `MaterialApp.router`, theme, l10n |
| Router | [lib/app/router.dart](../lib/app/router.dart) | `routerProvider`, all route paths |
| Linux runner | [linux/runner/my_application.cc](../linux/runner/my_application.cc) | GTK application, single-instance flags, window size |
| Rust API | [rust/src/api/tags.rs](../rust/src/api/tags.rs) | `read_tags_batch`, `read_covers_batch`, `read_original_cover` (bridged to Dart) |
| Makefile | [Makefile](../Makefile) | `make` lists targets: run, build, check, gen, reset-* |

## Directory map

### Dart: `lib/`

Sizes are scout counts: files / lines, generated files included where noted.

| Path | Files / lines | Purpose |
|---|---|---|
| `lib/main.dart` | 1 / 85 | Startup sequence, provider overrides |
| `lib/app/` | 20 / 2,023 | Shell, router, theme, window integration, navigation history |
| `lib/app/shell/` | | `app_shell.dart` (layout), `top_bar.dart` (incl. the rescan button, `features/library/widgets/library_rescan_button.dart`), `top_bar_search_field.dart` (live search), `missing_roots_notice.dart` (startup warning about missing music folders), `navigation_history.dart`, `app_destination.dart`, `sidebar/` (incl. `sidebar_playlists_section.dart`, `sidebar_playlists_rail.dart`), `window/` |
| `lib/core/database/` | 39 / 15,303 (incl. generated) | drift `LibraryDatabase`, tables, browse/paging queries, library counts (`library_stats_queries.dart`), folder queries (`folder_queries.dart`: directory counts and subtree reads), genre queries and name splitting (`genre_queries.dart`, `genre_names.dart`), text keys, key backfill, v4, v5 and v6 migrations, user-data tables (`user_data_tables.dart`: `plays`, `play_stats`, `playlists`, `playlist_entries`; triggers in `listen_history.drift`), FTS5 search (`library_search.drift`, `library_search_queries.dart`, `search_terms.dart`, `search_name_index.dart`), library root queries, playlist queries, writes, row models and cover keys (`playlist_*.dart`) |
| `lib/core/indexer/` | 16 / 1,614 | Folder walk, tag reading via Rust, diff, scan orchestration, covers |
| `lib/core/logging/` | 9 / 1,106 | Rotating file logger, redaction, session header, error folding |
| `lib/core/media_controls/` | 8 / 790 | Own MPRIS 2.2 server on D-Bus (`mpris/`) |
| `lib/core/open_files/` | 3 / ~230 | Files from the command line and "Open with": method channel to the Linux runner (`open_files_channel.dart`), `OpenFilesService` (validate with `localAudioPath`, read tags, `openTracks`), startup hook |
| `lib/core/paths/` | 2 / 160 | XDG directory resolution; `local_audio_path.dart` (`localAudioPath`: the one check that a path or `file:` URI from outside the library is a local audio file, returned in canonical spelling) |
| `lib/core/player/` | 34 / 3,192 (without `session/`: 5 / 798) | `PlayerService`, `PlayQueue`, `MediaKitBackend`, ReplayGain and output device (`ReplayGainSync`, `AlbumRunKeyCache`, `OutputDeviceSync`, `AudioOutputControl`, `MpvAudioOutput`), session persistence (`session/`) |
| `lib/core/settings/` | 14 / 1,516 | `settings.json` codec, file I/O, `SettingsNotifier`, applied appearance, preference groups for options not wired yet (`library_scan_prefs.dart` incl. `watchFolders`, `playback_prefs.dart` incl. ReplayGain and output device with `withAudioDevice`, `display_prefs.dart` and their codecs; nothing outside settings reads them) |
| `lib/features/home/` | 1 / 31 | Placeholder screen |
| `lib/features/library/` | 59 / 5,164 | Songs, Albums, Artists, Genres and Folders (grid or list, `library_view_modes.dart` keeps the view in memory; `genres/` has the round `GenreAvatar`, list and grid tiles, page and header; `widgets/round_grid_tile.dart` is the round grid cell shared with Artists; `folders/` has the pure `folder_tree.dart`, `folder_songs.dart` (subtree reads in tree order), `folders_provider.dart`, list and grid tiles, counts line, folder page and header, and the six folder actions in `folder_actions.dart` and `folder_menu.dart`), onboarding, library state machine, sort controls (field menu + direction arrow); `play_shuffle_actions.dart` (Play, Shuffle and queue buttons of album and artist headers), `artists/artist_header.dart`, `artists/artist_grid_tile.dart` |
| `lib/features/player/` | 30 / 3,472 | `PlayerBar`, Now Playing overlay, queue sheet, seek bar, shortcuts |
| `lib/features/playlists/` | 12 / 1,166 | Playlists grid and playlist page: `playlists_screen.dart`, `playlist_screen.dart` (page, delete and rename), `playlist_entries_view.dart` (drag to reorder), `optimistic_order.dart`, `playlist_page_data.dart` (reactive providers), `playlist_page_actions.dart`, `playlist_routes.dart` |
| `lib/features/search/` | 4 / 451 | Search page: `search_screen.dart` (states), `search_results_view.dart` and `search_section.dart` (groups), `search_providers.dart` (queries and name indexes) |
| `lib/features/settings/` | 30 / 2,128 | Settings screen sections (appearance, library, backup, advanced, about), library folders list and stats, log folder row, setting widgets, and "Coming soon" rows for options not wired yet (`coming_soon_rows.dart`, `*_setting_rows.dart`, `settings_chips_row.dart`, `settings_number_presets.dart`) |
| `lib/shared/` | 38 / 2,498 | Helpers and tiles used by library and search: `genre_summaries.dart` (genre rows from stored strings), `natural_compare.dart` (file-manager name and path order, `sortByNaturalPath`), `play_tracks.dart`, `enqueue_tracks.dart`, `format_duration.dart`, `directory_picker_provider.dart`, `root_rejection_message.dart`, `show_in_file_manager.dart`, `track_menu_actions.dart`, `track_menu_choice.dart`; `widgets/` has the tiles (`song_tile.dart`, `album_list_tile.dart`, `artist_tile.dart`), `queue_actions_menu.dart`, `track_actions_menu.dart`, `playlist_cover.dart`, `add_to_playlist/` (picker, name dialog, add flow), CoverArt, EmptyState, PageScaffold, ScanProgress, MinBusyBuilder |
| `lib/l10n/` | ARB + generated | `app_en.arb` (template), `app_vi.arb`; `app_localizations*.dart` is generated |

Key files by area:

| Area | Files |
|---|---|
| Playback | `core/player/player_service.dart`, `play_queue.dart`, `media_kit_backend.dart`, `mpv_playlist_tracker.dart`, `unavailable_audio_backend.dart` |
| Audio output | `core/player/replay_gain_sync.dart` with `album_run_key_cache.dart`, `output_device_sync.dart` (settings to engine), `send_audio_call.dart`, `player_audio_output.dart` (part of `PlayerService`), `replay_gain_options.dart`, `audio_device_choice.dart`, `audio_output_control.dart`, `mpv_audio_output.dart`, `mpv_startup_options.dart`, `album_run_lookup.dart`, `audio_output_devices_provider.dart` |
| Original cover | `core/player/original_cover_reader.dart`, `rust_original_cover_reader.dart`, `playing_track_original_cover.dart`; native init shared in `core/native/rust_library.dart`; shown by `features/player/now_playing/now_playing_artwork.dart` |
| Session restore | `core/player/session/playback_session_file.dart`, `playback_session_saver.dart`, `playback_session_codec.dart` |
| Indexing | `core/indexer/library_indexer.dart`, `walk_audio_files.dart`, `scan_diff.dart`, `tracks_from_tags.dart`, `rust_tag_reader.dart` |
| Playlists | `core/database/playlist_queries.dart`, `playlist_writes.dart`, `playlist_providers.dart`, `playlist_cover_keys.dart`; `shared/widgets/add_to_playlist/add_to_playlist_flow.dart`; `features/playlists/playlist_screen.dart`, `playlist_entries_view.dart`; `app/shell/sidebar/sidebar_playlists_section.dart` |
| Library DB | `core/database/library_database.dart`, `library_tables.dart`, `library_browse_queries.dart`, `library_browse_track_links.dart`, `library_browse_now_playing.dart` (album of the playing path), `library_browse_missing_roots.dart` (roots that are no longer folders), `library_song_paging.dart`, `library_keys_provider.dart`, `throttled_tracks_query.dart` |
| Search | `core/database/library_search.drift`, `library_search_queries.dart`, `search_terms.dart`, `search_name_index.dart`, `library_migration_v4.dart`; `features/search/search_providers.dart`, `search_screen.dart`; `app/shell/top_bar_search_field.dart`, `navigation_history.dart` |
| Startup DB | `core/database/library_startup.dart` |
| Library folders | `core/database/library_root_queries.dart` (watch, count, remove, replace; the settings UI no longer calls replace), `core/indexer/library_roots_controller.dart` (add, remove, replace), `core/indexer/library_startup_tasks.dart` (post-frame rescan), `features/settings/library_folders_list.dart` |
| MPRIS | `core/media_controls/mpris/mpris_media_controls.dart`, `mpris_method_handler.dart`, `mpris_properties.dart` |
| Browse UI | `features/library/library_browse_body.dart` (state machine), `songs/song_row_cache.dart`, `albums/album_screen.dart`, `artists/artist_screen.dart`, `genres/genre_screen.dart`, `folders/folder_screen.dart`; `features/player/now_playing/now_playing_album_line.dart` (album line in Now Playing) |
| Now Playing | `features/player/now_playing/now_playing_overlay.dart`, `now_playing_auto_hide.dart`, `now_playing_tabs.dart` |
| Settings | `core/settings/settings_provider.dart`, `settings_codec.dart`, `settings_file.dart`; library counts: `core/database/library_stats_queries.dart` + `features/settings/library_stats_provider.dart` |
| Logging | `core/logging/app_logging.dart`, `rotating_log_file.dart`, `log_redaction.dart` |
| Schema 6 tables | `core/database/library_tables.dart` (`CoverColors`, `ExcludedFolders`), `user_data_tables.dart` (`playlists.kind`, invariant 8), `library_migration_v6.dart`; reset rules in `packaging/dev/reset-library.sql` |

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
| `test/` | Dart tests; 229 `*_test.dart` files under `core/`, `features/`, `app/`, `shared/`, `drift/` |
| `test/drift/library_db/generated/` | **Generated** schema test code for v1–v6 |
| `drift_schemas/library_db/` | drift schema snapshots `drift_schema_v1..v6.json` (generated by `make-migrations`) |
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
| `lib/` (excludes `*.g.dart`, `lib/src/rust/`, `lib/l10n/`; includes the two generated files `library_database.steps.dart` and `text_key_tables.dart`) | 333 | 34,578 |
| `rust/src/` | 10 | 1,751 |
| `linux/` | 10 | 570 |
| `test/` (all `.dart`, helpers included) | 255 | 58,604 |

Largest non-generated Dart files: `core/indexer/library_indexer.dart` (553), `core/database/library_database.dart` (348), `core/player/media_kit_backend.dart` (422), `features/settings/full_or_compact_control.dart` (302). Generated and large: `core/database/text_key_tables.dart` (1,963, generated), `core/database/library_database.steps.dart` (1,654, generated).

Non-generated Dart files over the 200-line guideline in [CLAUDE.md](../CLAUDE.md) are candidates for splitting: 18 of them, the largest listed above. The search files are all under 200 lines.

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
| `test/core/database/` | Browse queries, paging, keys, backfill, migrations, search index and queries; benchmarks gated by `KANARU_BENCH=1` |
| `test/core/indexer/` | Walk, diff, scan orchestration; `fake_tag_reader.dart`, `scripted_indexer.dart` |
| `test/core/media_controls/` | MPRIS with an in-process D-Bus harness |
| `test/core/logging/`, `settings/`, `paths/` | Unit tests |
| `test/drift/library_db/` | `migration_test.dart` against generated schemas |
| `test/features/library/` | Browse UI; `library_test_harness.dart` (`LibraryHarness`, in-memory DB) |
| `test/features/playlists/` | Playlists: queries (`test/core/database/playlist_*`), grid, page, drag reorder, sidebar section, add-to-playlist flow and menus, Now Playing button; `playlist_test_data.dart` seeds playlists |
| `test/features/search/` | Search page: states, sections, show all, song tap and queue menu |
| `test/features/player/` | Player bar, Now Playing layout and auto-hide, volume popup |
| `test/features/settings/` | Settings widgets |
| `test/app/`, `test/shared/` | Router, shell, shared widgets |
| `rust/tests/`, `#[cfg(test)]` | 43 integration and 10 unit tests (format fixtures) |

Counts are from the scout snapshot; the last full run on `feat/library-browse-2` (2026-10-23) reported 2,243 passing and 11 skipped Dart tests. Commands and helper details: [development.md](./development.md#tests--lints) and [code-standards.md](./code-standards.md#testing).

## Compaction

```bash
repomix --style xml -o repomix-output.xml \
  --ignore "**/*.g.dart,lib/src/rust/**,rust_builder/**,drift_schemas/**,test/drift/library_db/generated/**,lib/core/database/text_key_tables.dart,**/*.freezed.dart,docs/**,plans/**,linux/flutter/**,pubspec.lock"
```

Output for the 2026-10-21 snapshot: 356 files, about 402k tokens. The compaction is a local artifact; do not commit it.
