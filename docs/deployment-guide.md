# Deployment guide

How Kanaru is built, run and reset today, and what is still missing before it can be released. As of 2026-10-21 there is **no release process**: no tags, no packages, no CI workflow, and no installer. Users build from source; the only artifact is the Flutter Linux bundle.

Dev setup (toolchain, distro packages, codegen) is in [development.md](./development.md). This page covers building for use, runtime requirements and data locations.

## Status

| Item | State | Evidence |
|---|---|---|
| Release build target | Works | `Makefile` target `build` |
| Version injection | Works, but `make build` does not pass it | `KANARU_VERSION` read in `lib/core/logging/app_logging.dart` |
| CI | **Not started** | No `.github/` directory |
| Packages (AppImage, Flatpak, deb, rpm, AUR, Nix) | **Not started** | No manifests or recipes; `flake.nix` has only `devShells.default` |
| Desktop entry and icon | **Not started** | No `.desktop` file in `linux/`; MIME association (SYS-07) open |
| Tags and changelog | **Not started** | `git tag` is empty; no changelog file |

## Build a release bundle

```bash
make build
# same as: flutter build linux --release
```

To stamp a version (shown in the first log line of each session):

```bash
flutter build linux --release --dart-define=KANARU_VERSION=0.1.0
```

`make build` does not pass `KANARU_VERSION`, so release builds made through it log the version as `dev`. Pass the define yourself for any build you hand out.

Output:

| Path | Content |
|---|---|
| `build/linux/<x64 or arm64>/release/bundle/kanaru` | Executable |
| `build/linux/<x64 or arm64>/release/bundle/lib/` | Bundled shared libraries, including libmpv |
| `build/linux/<x64 or arm64>/release/bundle/data/` | Flutter assets, ICU data, native assets |

Run it from the bundle directory:

```bash
./build/linux/x64/release/bundle/kanaru
```

Install by copying the bundle directory (for example to `~/.local/opt/kanaru`). There is no installer, no desktop entry and no icon yet, so the app will not appear in launchers or in "Open with" menus.

### Build-time network

The `media_kit_libs_linux` plugin downloads a prebuilt libmpv archive during the first build and checks its MD5 before use. A build on a machine without network access fails at that step unless the archive is already in the plugin's cache.

Rust is built by cargokit inside `flutter build`. The first build is slow. Use `--locked` for the crate; see [development.md](./development.md#code-generation).

## Runtime requirements

| Requirement | Release bundle | Notes |
|---|---|---|
| Flutter engine, ICU, assets | Bundled | |
| libmpv | Bundled | Fetched at build time by `media_kit_libs_linux` (see above). |
| Rust tag reader | Bundled | Shared library built by cargokit from `rust/`, bundled through `rust_builder`. |
| GTK 3 | System | Required by the Flutter Linux embedder. |
| SQLite | System | Library database. The dev docs require SQLite 3.35 or newer; confirm the system library version on your distro. |
| GSettings schemas (GTK) | System | Needed by GTK file pickers (folder picker). Distros ship them with GTK 3. |
| D-Bus session bus | Optional | Needed for MPRIS. The app runs without it, with no media controls. |
| Secret Service (libsecret) | Not needed yet | No credential storage in the code yet. Needed once remote sources land (PRIV-04). |

Not linked today: `libsecret`, `jsoncpp`. `development.md` lists them as build dependencies for `flutter_secure_storage`, which is not in `pubspec.yaml` yet.

Desktop environments: the bundle is GTK 3 and talks to the compositor through the normal X11 or Wayland path. Known limit on compositors that need xdg-activation (verified on niri): a second launch or MPRIS `Raise` does not bring the window forward (SYS-15).

## Environment variables

| Variable | Default | Effect |
|---|---|---|
| `KANARU_LOG_LEVEL` | `ALL` in Debug, `INFO` in Profile and Release | `package:logging` level name, any case. Unknown values keep the default and log a warning. |
| `XDG_CONFIG_HOME` | `~/.config` | Config directory parent. Relative or empty values are ignored. |
| `XDG_DATA_HOME` | `~/.local/share` | Data directory parent. |
| `XDG_CACHE_HOME` | `~/.cache` | Cache and log directory parent. |
| `KANARU_VERSION` (build-time define) | `dev` | Shown in the session header of the log. |
| `KANARU_BENCH` | unset | Set to `1` to run the 100k-track benchmarks (tests only). |

## Data locations

| Kind | Path | Contents |
|---|---|---|
| Config | `$XDG_CONFIG_HOME/kanaru` (default `~/.config/kanaru`) | `settings.json`, `playback-session.json` |
| Data | `$XDG_DATA_HOME/kanaru` (default `~/.local/share/kanaru`) | `library.db` (with `-wal` and `-shm` files while running) |
| Cache | `$XDG_CACHE_HOME/kanaru` (default `~/.cache/kanaru`) | `covers/512/` thumbnails, `covers/` temporary files, `logs/` |
| Logs | `$XDG_CACHE_HOME/kanaru/logs` | `kanaru.log`, `.1` to `.4`, `kanaru.lock`, and `kanaru-<pid>.log` for extra instances |

Backups: copy the config and data directories while Kanaru is closed. The cache can be deleted at any time; covers are rebuilt on the next scan.

Secrets are never written to these files (planned keyring storage for remote sources, PRIV-04). Log lines are redacted for passwords, tokens and URL credentials on a best-effort basis.

## Reset targets

Quit Kanaru first. `reset-covers` and `reset-all` are `Makefile` rules that run `rm -rf` on the paths shown. `reset-library` runs [packaging/dev/reset-library.sql](../packaging/dev/reset-library.sql) with the `sqlite3` CLI (from `PATH`, else from the Nix dev shell; non-Nix users need `sqlite3` 3.35+ with FTS5). It refuses to run while a process has `library.db` open.

| Command | Removes | Keeps | Next start |
|---|---|---|---|
| `make reset-covers` | `cache/covers` | everything else | Covers read again on the next scan |
| `make reset-library` | Library folders, tracks, track artists and the search index inside `library.db`; `cache/covers` | Playlists, listen history and play counts, settings, session | Folder picker shows again (no library folders); the old playlist entries and plays match again by path once the same files are scanned |
| `make reset-all` | `data`, `config`, `cache`: library, **playlists, listen history**, settings, playback session, covers, logs | nothing | Like a fresh install |
| `make logs` | nothing | everything | Follows `kanaru.log` |

`reset-library` lists its tables explicitly: when a table derived from the scan is added, update the SQL. For a throwaway dev schema change that is not worth migrating, use `make reset-all` (it also deletes playlists and listen history; see [development.md](./development.md#code-generation)).

## Single instance

Release and Profile builds are single-instance (GTK application uniqueness). A second launch activates the running window and exits. Debug builds run side by side, so `flutter run` always starts. This means a `flutter run --release` does not open while a release build is running.

## Packaging plan

Planned from [features.md section 18](./features.md). None of these exist yet.

| ID | Target | Priority | Current state | Notes for the packaging work |
|---|---|---|---|---|
| PKG-01 | AppImage | P0 | Not started | Bundle libmpv and GTK; add a desktop file and icon. Size target under 60 MB (NFR-04). |
| PKG-02 | Flatpak (Flathub) | P1 | Not started | Music folder access only through the file chooser portal. `flatpak-builder` is in the dev shell. |
| PKG-03 | `.deb` and `.rpm` | P1 | Not started | Declare `libmpv2`, `libsecret-1-0` (once needed) and GTK 3 as dependencies. |
| PKG-04 | AUR `kanaru-bin` | P2 | Not started | Depends on a published binary. |
| PKG-05 | Nix package | P2 | Not started | Only the dev shell is defined in `flake.nix`. |
| PKG-08 | Schema history collapse | P0 | Not started | Must happen before the first release; see [system-architecture.md](./system-architecture.md#7-library-database-schema). |

Before the first package: add the desktop entry (SYS-07) and icon, set the release version in `pubspec.yaml`, and decide on a tag format.

## Release checklist (manual until CI exists)

1. `git status` is clean on `main`; PRs for the release are merged.
2. `make check` passes (analyze, Dart tests, `cargo test --locked`).
3. `make gen` and `make gen-rust` leave no diff in generated files.
4. Bump `version:` in `pubspec.yaml` (currently `0.1.0+1`).
5. `flutter build linux --release --dart-define=KANARU_VERSION=<version>`.
6. Smoke test the bundle: `make reset-all` first; start; add a folder; scan; play; `playerctl -p kanaru status`; restart and check the queue is restored paused.
7. Check `~/.cache/kanaru/logs/kanaru.log` for errors from the run.
8. Tag the commit and publish the bundle. The tag format and changelog are not decided yet.

Steps 2 to 4 become CI jobs once workflows exist. The repo has no `.github/` directory today.

## Troubleshooting for installed builds

| Symptom | Check |
|---|---|
| App starts in library-only mode, play does nothing | Log line "Audio engine failed to initialize". Check the bundle `lib/` has libmpv. |
| Folder picker does not open | GTK schemas missing: install the GTK 3 package of your distro. |
| Library empty after start | Check Settings → Library: the folders must exist (a missing one is struck through) and "Rescan when Kanaru opens" should be on. Press the rescan button. |
| Window does not come forward on second launch under niri | Known limit (SYS-15). |
| Anything else | Attach the log: `kanaru.log` and any `kanaru-<pid>.log` from the same time. Logs are not sent anywhere. |
