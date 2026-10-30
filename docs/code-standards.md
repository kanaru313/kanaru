# Code standards

Rules the code already follows, with the reason for each. Check a rule against the referenced file before you rely on it. Layout and module purposes are in [codebase-summary.md](./codebase-summary.md).

## Layering

Dependency direction: `app → features → core`, with `shared` allowed to use `core`.

| From | May import | Must not import |
|---|---|---|
| `lib/app/` | `features/`, `core/`, `shared/` | nothing above it |
| `lib/features/<x>/` | `core/`, `shared/` | `app/`, other `features/<y>/` |
| `lib/shared/` | `core/`, `l10n/` | `app/`, `features/` |
| `lib/core/` | `core/` | `app/`, `features/`, `shared/` |

Checked by grep on the 2026-10-21 snapshot, over relative imports: no feature imports `app/`, no feature imports another feature, no `core/` file imports `features/`, `app/` or `shared/`, and only `core/` imports `src/rust/` (`core/indexer/rust_tag_reader.dart`, `core/native/rust_library.dart`, `core/player/rust_original_cover_reader.dart`, `core/cover_colors/rust_cover_color_extractor.dart`, `core/lyrics/rust_embedded_lyrics_reader.dart`), each behind a Dart interface that tests replace with a fake.

Rules that follow from it:

- **Shared code moves down.** If two features need the same thing, move it to `shared/` (widgets, formatting) or `core/` (logic). Do not import the other feature.
- **Features cannot reach the shell.** The Now Playing title bar is injected by `app/shell`, not imported by `features/player`. Same for the router: features never import `app/router.dart`.
- **Route literals are duplicated on purpose.** `shared/library_route_keys.dart` declares `albumsPath = '/albums'`, `artistsPath = '/artists'`, `genresPath = '/genres'` and `foldersPath = '/folders'` because `shared/` and features cannot import `app/`. A test checks them against the shell destinations (`lib/app/shell/app_destination.dart`). Features that own a destination declare its literal the same way (`playlistsPath`, `favoritesPath` in `features/playlists/`, `historyPath` in `features/history/`), with a test against the destination. If you change a route, change both and keep the test passing.
- **Route keys.** Album, artist, genre, folder and album-artist keys in URLs are `base64Url(utf8(json([...parts])))` without padding, length-capped (`_maxRouteKeyLength`). Build them with the helpers in `library_route_keys.dart`; do not hand-assemble paths.
- **Imports** inside `lib/` are relative (`'../../core/...'`), as in the rest of the code. Apply the layering table to the resolved path, not to the import style.

## Flutter and UI library

- **Use `package:material_ui/material_ui.dart`**, not `package:flutter/material.dart`. 87 files import `material_ui`; none import `flutter/material.dart`. Import `flutter/widgets.dart` or `flutter/services.dart` only where the widget library is not enough.
- **Theme** lives in `lib/app/theme.dart`. Use theme tokens and `Theme.of(context)`; avoid hard-coded colors outside the placeholder palette (`shared/widgets/placeholder_colors.dart`). A white icon over a darkened image (scrim or black overlay) is allowed, e.g. the Now Playing cover button and the equalizer on the playing song's cover in `song_tile_cover.dart`.
- **Icons go through `AppIcons`** (`lib/shared/icons/app_icons.dart`), never `Icons.` directly. Add a new icon there, named by meaning. `test/shared/icons/app_icons_usage_test.dart` enforces it.
- **Layout numbers** that are shared across a file sit at file level as `const` values with a `///` doc. Breakpoints are named constants, not inline literals (see [design-guidelines.md](./design-guidelines.md#breakpoints)).
- **Strings**: every user-visible string comes from `context.l10n` (see [Localization](#localization)).

## Riverpod

Version: `flutter_riverpod` 3.4. **No code generation**: no `riverpod_generator`, no `@riverpod`. `build_runner` is used only for drift.

| Rule | Example |
|---|---|
| Providers are top-level `final` declarations named `xProvider` | `settingsProvider` in `core/settings/settings_provider.dart` |
| Use `Provider`, `NotifierProvider(Class.new)`, `StreamProvider` (`.autoDispose` where the stream is screen-scoped), `FutureProvider` | `playerServiceProvider = NotifierProvider<PlayerService, PlayerState>(...)` |
| All notifiers extend plain `Notifier<T>` | `PlayerService extends Notifier<PlayerState>` |
| Narrow rebuilds with `select` and records | `ref.watch(p.select((s) => (a, b)))` |
| Injection seams are providers that default to a placeholder and are overridden in `main()` or tests | `initialSettingsProvider`, `settingsFileProvider`, `audioBackendOverride`, `mediaControlsProvider` |
| Never invalidate a settings provider; the notifier writes through | `SettingsNotifier` ([settings_provider.dart](../lib/core/settings/settings_provider.dart)) |

Startup overrides are assembled in [lib/main.dart](../lib/main.dart) into one manual `ProviderContainer` wrapped by `UncontrolledProviderScope`. Tests use the same override mechanism instead of mocking the framework.

## Widgets and files

- **One public widget per file.** Private helpers are `_Sub` widgets in the same file.
- **File names** are `snake_case.dart`. Types are `UpperCamelCase`, members `lowerCamelCase`. Rust files are `snake_case.rs`.
- **Size.** Files over about 200 lines are candidates for splitting (CLAUDE.md). Current largest hand-written Dart: `core/indexer/library_indexer.dart` (624). Split on a real boundary (state, painter, gesture) and keep the public widget name stable.
- **Comments explain why.** Dense, short comments are the norm in this codebase. Use `///` for public API and for file-level constants; use `//` for non-obvious reasoning. Do not restate the code.
- **Comments carry no plan IDs, phase numbers, audit labels or finding codes.** Write the invariant or behavior instead. Feature IDs from [features.md](./features.md) (for example `IDX-03`) are the one exception when they name a user-facing requirement.
- **Accessibility.** Sliders expose semantics. Focus is restored after an overlay or sheet closes. Reduced motion is respected everywhere (see [design-guidelines.md](./design-guidelines.md#motion-and-reduced-motion)).

## Isolates

- Heavy file walks and cover work run in `Isolate.run`. Example: `core/indexer/walk_audio_files.dart`, `core/indexer/cover_cache_cleanup.dart`.
- Pass only top-level functions or closures that capture sendable values (paths, ints, strings). Do not capture `Ref`, providers, `LibraryDatabase` or stream subscriptions.
- Database work in another isolate uses drift's `computeWithDatabase` (`core/database/library_keys_provider.dart`) so the connection is opened on the worker.
- The library database opens with `NativeDatabase.createInBackground` (its own isolate); the UI thread does not run SQLite queries directly.

## Error handling

| Pattern | Where | Behavior |
|---|---|---|
| **Fail soft at bootstrap** | `main.dart` | Each step catches its own error and degrades: no engine → `UnavailableAudioBackend` (library-only mode); broken settings → defaults; window setup failure → system title bar; library open failure → no library, playback still works. Nothing in bootstrap throws to hide the window. |
| **Load never throws** | `core/settings/settings_file.dart`, `playback_session_file.dart` | Missing file → defaults. Invalid file → renamed to `*.invalid`, defaults used. Newer schema version or unreadable file → read-only session (no writes that would destroy data). |
| **Atomic writes** | settings and session files | Write to a temporary file in the same directory, then rename. Writes resolve symlinks first. The settings saver keeps one write in flight plus one pending. |
| **Quarantine** | invalid JSON / invalid session | Move aside to `<name>.invalid`; never delete user data. |
| **Logging never throws** | `core/logging/` | The write path swallows its own failures and falls back to stderr when the log file cannot be opened. Logs are redacted (`log_redaction.dart`) and repeated errors are folded for 10 s. |
| **Playback errors** | `core/player/` | A track that never reports duration is treated as failed. When every queued track fails in a row, the queue stops (no endless retry). |
| **Scan errors** | `core/indexer/` | Per-file parse errors are stored on the track row (`scan_error`). Permanent errors are not retried until the file changes or `tagReaderVersion` changes. Transient I/O errors are retried on every scan. Stalled walks and tag batches time out at 60 s and trigger one automatic rescan. |
| **Snackbar content** | any `showSnackBar` | Build snackbars with `appSnackBar(kind:, title:, details:)`, or `AppSnackBarContent` inside a `SnackBar` when the text must rebuild; never `SnackBar(content: Text(...))`. Never set `margin`, `behavior`, colors or shape at a call site: the frame comes from the theme. |
| **Snackbar with an action** | any `SnackBar(action: …)` | Set `persist: false` and an explicit `duration`. `material_ui` defaults `persist` to true when there is an action, so a snackbar with an action and no `persist: false` never closes by itself. Close a snackbar you own only while it is the one on screen (`onVisible` seen, not yet closed); closing another one hides whichever is current. |
| **Rust** | `rust/src/tag_batch.rs` | A batch never fails as a whole: each path gets a `TrackTags` result. Each file is wrapped in `catch_unwind`, so do not set `panic = "abort"` in the Cargo profile. |

## Version constants

Four constants tell the app to redo work on existing libraries. Bump only the one that matches your change. The full procedure is in [development.md](./development.md#library-version-constants).

| Constant | Location | Bump when |
|---|---|---|
| `textKeysVersion` | `lib/core/database/text_keys.dart` (currently `2`) | Rules of `groupKey`, `sortKey`, `artistSortKey` change, a Dart SDK change alters `toLowerCase` output, or `trackKeysFor` starts writing a new key |
| `coverScanVersion` | `lib/core/database/library_rows.dart` (currently `1`) | Cover extraction or thumbnail rules change (also when `THUMBNAIL_SIDE` or the `covers/<size>` directory changes) |
| `tagReaderVersion` | `lib/core/database/library_rows.dart` (currently `1`) | The Rust reader starts accepting files it used to reject |
| `coverColorAlgoVersion` | `lib/core/cover_colors/cover_palette.dart` (currently `100512`: `coverColorAlgoRevision * 100000 + coverThumbnailSize`) | Bump `coverColorAlgoRevision` together with `COLOR_ALGO_REVISION` in `rust/src/cover_colors.rs` when the colors for the same thumbnail change; a new thumbnail size changes it by itself |
| `PERMANENT_ERROR_PREFIX` | `rust/src/tag_reader.rs` (currently `permanent:v1:`) | Must carry the same `N` as `tagReaderVersion` |

Other version numbers that must stay in step:

- `schemaVersion` in `core/database/library_database.dart` (currently `11`). After bumping it, run `make migrations`.
- `flutter_rust_bridge` (Dart package, crate, and codegen binary) are pinned to `2.13.0`. Change all three together.
- `KANARU_VERSION` is passed at build time with `--dart-define` (see [deployment-guide.md](./deployment-guide.md#build-a-release-bundle)).

## Generated code

Never edit these by hand. Regenerate and commit the output:

- `*.g.dart` (drift)
- `lib/core/database/library_database.steps.dart`, `drift_schemas/library_db/`, `test/drift/library_db/generated/`
- `lib/src/rust/`, `rust/src/frb_generated.rs`
- `lib/core/database/text_key_tables.dart`: change `tool/generate_text_key_tables.py` and rerun it
- `lib/l10n/app_localizations*.dart`

Commands are in [codebase-summary.md](./codebase-summary.md#generated-code).

## Localization

- Template: `lib/l10n/app_en.arb`. Second language: `lib/l10n/app_vi.arb`. Config: `l10n.yaml` (`nullable-getter: false`).
- Add a key to `app_en.arb` first, then `app_vi.arb`, then regenerate (`flutter gen-l10n` or any build).
- Access strings as `context.l10n.<key>` (extension in `lib/l10n/l10n.dart`). Do not put literal UI text in widgets.
- Settings offer language *system / en / vi*; the app follows the system locale by default.

## Naming

| Thing | Convention | Example |
|---|---|---|
| Dart file | `snake_case.dart` | `playback_session_saver.dart` |
| Dart type | `UpperCamelCase` | `MediaKitBackend` |
| Dart member, provider | `lowerCamelCase`; providers end with `Provider` | `openTracks`, `routerProvider` |
| Private | leading `_` | `_compactBelow` |
| Rust crate | `rust_lib_kanaru` | `rust/Cargo.toml` |
| Linux app ID | `io.github.kanaru313.kanaru` | `linux/CMakeLists.txt` |
| Settings / session JSON keys | `camelCase` | `librarySort`, `albumsView` |
| D-Bus bus name | `org.mpris.MediaPlayer2.kanaru` | `mpris_bus_name.dart` |

## Linting and formatting

- `flutter analyze` with `flutter_lints` 6. Excluded from analysis: `build`, `linux`, `rust_builder`.
- `dart format lib test` (`make format`). Generated files are formatted only when you regenerate them (`dart format` after `text_key_tables.dart`).
- Rust: `cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings`.

## Testing

Commands: [development.md](./development.md#tests--lints). Layout: [codebase-summary.md](./codebase-summary.md#tests).

- **Fakes over mocks.** Shared fakes live next to the tests that use them: `FakeAudioBackend` (`test/core/player/`), `FakeTagReader` and `ScriptedIndexer` (`test/core/indexer/`).
- **In-memory database.** `LibraryHarness` (`test/features/library/library_test_harness.dart`) opens an in-memory `LibraryDatabase`.
- **D-Bus.** MPRIS tests run an in-process D-Bus harness; they do not need a session bus.
- **Migrations.** `test/drift/library_db/migration_test.dart` checks each step against the generated schema tests. Extend its data-integrity test by hand for every new step.
- **Golden text keys.** `test/core/database/text_keys_test.dart` (`keys of a fixed corpus match the recorded output`). If the output changes on purpose, bump `textKeysVersion` and update the recorded output in the same change.
- **Benchmarks** are skipped unless `KANARU_BENCH=1`. They print timings; the repo stores no reference numbers.
- **Narrow first.** Run the affected test file, then the broader suite (`make test T=test/core/indexer`).
- **Do not weaken tests to pass.** Fix the code or the test's assumption, and say which.

## Rust

- Edition 2021, rust 1.89 minimum (`rust/Cargo.toml`).
- Pinned crates: `lofty =0.25.4`, `image =0.25.10` (jpeg, png, webp), `blake3 =1.8.7` (pure Rust), `symphonia =0.6.1` (MPL-2.0; features `mp3 flac ogg vorbis aac alac isomp4 pcm wav id3v2`, no default features), `flutter_rust_bridge =2.13.0`. Use `--locked` for builds and tests.
- Profile: `opt-level = 3` in dev too (thumbnails are about 90 times slower otherwise). Keep `panic` at its default (`unwind`).
- File opens use `O_NONBLOCK` (through `libc`, see `rust/src/cover_art.rs`), so a FIFO cannot block a batch.
- Rayon pool is named `kanaru-tags-N`, sized `max(cpus/2, 2)`, with 8 MiB stacks.
- Public API lives in `rust/src/api/` only. The bridge reads `crate::api` (`flutter_rust_bridge.yaml`).
- Text limits are enforced in Rust: 1 KB for title, artist, album, album artist, genre, composer; 128 bytes language; 4 KB comment; 32 artists. Covers are capped at 4096 px (a baseline JPEG, decoded scaled down, up to 8192 px), 16 MB source, 64 MB decode; the alpha blend and resize work on the decoded buffer, so the peak stays near the decode size (RGBA 4096² measured at about 74 MiB).

## Commits and branches

- **Conventional commits**: `type(scope): subject`, lowercase, imperative. Types in use: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`. Scopes: `library`, `player`, `indexer`, `mpris`, `shell`.
- **No AI references** in commit messages, PR titles or PR bodies.
- Commits for `.claude/` files must not use `chore` or `docs` in the message (project rule in CLAUDE.md).
- Branches: `feat/<slug>`, `fix/<slug>`; one PR per feature into `main`. Parallel work uses worktrees per [.claude/rules/parallel-worktrees.md](../.claude/rules/parallel-worktrees.md).
- Keep commits focused. Never commit `.env` files, credentials or tokens.

## Dependencies

- Add a package only when it removes real complexity. Pin Rust crates exactly.
- Before adding a dependency, check [features.md](./features.md) for the feature it serves and [system-architecture.md](./system-architecture.md) for where it belongs.
- `flutter_secure_storage` is in `pubspec.yaml` (used only through `lib/core/secrets/`). Planned dependencies (`shelf`, `audio_service`, `smtc_windows`, `material_color_utilities`) are **not** in `pubspec.yaml` yet.
