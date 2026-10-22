# Development setup

Kanaru currently targets **GNU/Linux** first. Windows, macOS, Android and iOS instructions will be added in phase 2.

## What you need

| Tool | Version | Why |
|---|---|---|
| Flutter (stable) | ≥ 3.47 (Dart ≥ 3.13) | App framework |
| Clang, CMake, Ninja, pkg-config | any recent | Flutter Linux desktop toolchain |
| GTK 3 (dev headers) | ≥ 3.24 | Flutter Linux embedder |
| libmpv (dev headers) | ≥ 0.36 | Audio playback (`media_kit`) |
| libsecret, jsoncpp (dev headers) | any recent | Planned credential storage (`flutter_secure_storage`, not in `pubspec.yaml` yet); installing them now keeps the setup stable |
| SQLite (dev headers) | ≥ 3.35 | Library database (`drift`) |
| Rust (stable) + Cargo | ≥ 1.89 | Tag reading (`lofty` via `flutter_rust_bridge`) |
| libclang | any recent | Needed by `flutter_rust_bridge_codegen` / `ffigen` |
| `flutter_rust_bridge_codegen` | 2.x | Generates Dart ↔ Rust bindings |

Pick the section for your system, then continue with [Verify](#verify).

---

## Nix / NixOS (recommended)

The repo ships a `flake.nix` dev shell with everything above pinned via `flake.lock`.

```bash
# one-off
nix develop

# or automatically on cd (requires direnv + nix-direnv)
direnv allow
```

Notes:
- Flakes must be enabled (`experimental-features = nix-command flakes`).
- Flutter from nixpkgs cannot `flutter upgrade` itself. Update tools with `nix flake update`.

## Debian / Ubuntu

```bash
sudo apt update
sudo apt install -y \
  curl git unzip xz-utils zip \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libmpv-dev mpv \
  libsecret-1-dev libjsoncpp-dev \
  libsqlite3-dev libclang-dev
```

Ubuntu ≥ 22.04 / Debian ≥ 12 is recommended. Older releases ship a libmpv that is too old.

## Fedora

```bash
sudo dnf install -y \
  git curl unzip xz zip \
  clang clang-devel cmake ninja-build pkgconf-pkg-config \
  gtk3-devel xz-devel \
  mpv mpv-devel \
  libsecret-devel jsoncpp-devel \
  sqlite-devel
```

If `mpv-devel` is not found on your release, enable [RPM Fusion](https://rpmfusion.org/Configuration) first.

## Arch Linux / Manjaro

```bash
sudo pacman -S --needed \
  base-devel git curl unzip zip \
  clang cmake ninja pkgconf \
  gtk3 mpv libsecret jsoncpp sqlite
```

Flutter is available from the AUR (`flutter-bin`), or install it manually as below.

## Installing Flutter (non-Nix)

Choose one:

- **Manual (official):** follow <https://docs.flutter.dev/get-started/install/linux/desktop>.
  Download the stable tarball, extract it (for example to `~/development/flutter`), then add `flutter/bin` to your `PATH`.
- **Snap:** `sudo snap install flutter --classic`
- **[fvm](https://fvm.app)** if you juggle several Flutter versions.

Then enable the Linux desktop target:

```bash
flutter config --enable-linux-desktop
```

## Installing Rust (non-Nix)

Use [rustup](https://rustup.rs) rather than distro packages, which are often too old:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install flutter_rust_bridge_codegen
```

If codegen fails with *"Unable to find libclang"*, point it to your libclang directory:

```bash
export LIBCLANG_PATH=/usr/lib/llvm-18/lib   # adjust to your system
```

---

## Verify

```bash
flutter doctor            # "Linux toolchain" must be ✓ (Android/Chrome can be ignored for now)
pkg-config --modversion gtk+-3.0 mpv libsecret-1 jsoncpp sqlite3
rustc --version
flutter_rust_bridge_codegen --version
```

Every `pkg-config` line should print a version number. If one prints *"Package … was not found"*, its `-dev`/`-devel` package is missing.

## Running

```bash
flutter pub get
flutter run -d linux
```

The `Makefile` wraps the everyday commands (`make` lists them): `make run`, `make check` (analyze + Dart and Rust tests), `make gen`, `make logs`, and `make reset-library` / `make reset-all` to start again from the first-run folder picker (quit Kanaru first). Without `flutter` on PATH, targets run inside `nix develop`.

### Code generation

Run code generation again after changing drift tables or Rust APIs:

```bash
# Dart (drift)
dart run build_runner build --delete-conflicting-outputs

# Rust bindings (after changing rust/src/api)
RUSTC_BOOTSTRAP=1 flutter_rust_bridge_codegen generate

# After bumping schemaVersion in the library database: new migration step + test
dart run drift_dev make-migrations
```

`make-migrations` snapshots the schema into `drift_schemas/library_db/drift_schema_v<N>.json`, rewrites `lib/core/database/library_database.steps.dart` (the `stepByStep` helper; wire the new `fromXToY` callback in `LibraryDatabase.migration`) and regenerates `test/drift/library_db/generated/`. Bump `schemaVersion` before running it. `test/drift/library_db/migration_test.dart` is created only when missing: extend its data-integrity test by hand for each new step. Commit the snapshot, the steps file and the generated test schemas.

Kanaru has not been released yet, so these steps only spare dev machines a rescan; `make reset-library` is an acceptable alternative. Right before the first release the schema history is collapsed into v1 (PKG-08 in `docs/features.md`).

In the Nix dev shell, `dart run` cannot find the Flutter SDK ("flutter_test from sdk which doesn't exist"). Use `flutter pub run build_runner build --delete-conflicting-outputs` and `flutter pub run drift_dev make-migrations` there instead.

Notes on the Rust side:

- **Pinned codegen**: the Dart `flutter_rust_bridge` package, the crate and `flutter_rust_bridge_codegen` must all be 2.13.0 (`flutter_rust_bridge_codegen --version`). The dev shell provides the codegen binary; outside Nix, `cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked`.
- **`RUSTC_BOOTSTRAP=1`**: codegen runs `cargo expand`, which needs nightly features. The variable lets the stable toolchain do it. The dev shell ships `cargo-expand`; elsewhere `cargo install cargo-expand`.
- **`rustup` shim (Nix only)**: the build glue (cargokit) calls `rustup toolchain list`, `rustup target list --installed` and `rustup run <toolchain> cargo`. Nix provides one fixed toolchain and no rustup, so the dev shell has a tiny `rustup` script that answers exactly those three calls and fails on anything else. Without it `flutter run` fails while building the Rust crate. Cargokit looks for `~/.cargo/bin/rustup` before `PATH`, so a real rustup install bypasses the shim.
- **Rust builds** happen inside `flutter run` / `flutter build` (cargokit builds the crate in debug for debug app builds and in release otherwise). The first build is slow, and each git worktree has its own `rust/` build output.
- **Optimized dev profile**: `rust/Cargo.toml` sets `[profile.dev] opt-level = 3`, so debug app builds (`flutter run`, `flutter build linux --debug`) ship an optimized Rust library; unoptimized image decoding and resizing make a first scan with covers many times slower. Debug info and debug assertions stay on. To step through Rust with variables that are not optimized away, build with `CARGO_PROFILE_DEV_OPT_LEVEL=0 flutter run -d linux`. Cargokit passes the variable on to cargo, and cargo rebuilds the library when it changes (checked: the `.so` was rebuilt with no folder deleted, and rebuilt again once the variable was dropped). The library then runs many times slower, so unset the variable for normal work.
- **Tests**: `cargo test --locked --manifest-path rust/Cargo.toml` (`--locked` fails if `Cargo.lock` is out of date).

### Library version constants

Three constants tell the app to redo work on libraries that already exist. Bump only the one that matches your change.

| Constant | Where | Bump when | Effect on existing libraries |
|---|---|---|---|
| `textKeysVersion` | `lib/core/database/text_keys.dart` | a rule in `groupKey`, `sortKey` or `artistSortKey` changes, a Dart SDK upgrade changes `toLowerCase` output, or `trackKeysFor` starts writing a new key | Rows with an older version are keyed again in the background on the next start. Album, artist and sort order come from these keys. |
| `tagReaderVersion` | `lib/core/database/library_rows.dart` | the Rust reader learns to read files it used to reject | Files marked permanently unreadable by an older reader are read again on the next scan. |
| `PERMANENT_ERROR_PREFIX` | `rust/src/tag_reader.rs` | bumped together with `tagReaderVersion` | Its `permanent:v<N>:` prefix must carry the same `N` as `tagReaderVersion`. |

Steps for `textKeysVersion`:

1. Change the rule in `text_keys.dart` and increase `textKeysVersion` by one.
2. Update the recorded output in `test/core/database/text_keys_test.dart` (`keys of a fixed corpus match the recorded output`) to the new keys, if the change is intended.
3. Run `flutter test test/core/database/text_keys_test.dart`.

After a Dart SDK upgrade, that golden test failing means `toLowerCase` changed for some input. Bump `textKeysVersion` and update the recorded output in the same change.

Steps for `tagReaderVersion`:

1. Change `tagReaderVersion` in `library_rows.dart`.
2. Change `PERMANENT_ERROR_PREFIX` in `rust/src/tag_reader.rs` to the same number.
3. Run `cargo test --locked --manifest-path rust/Cargo.toml` and `flutter test test/core/indexer`.

`lib/core/database/text_key_tables.dart` (accent and decomposition data) is generated by `tool/generate_text_key_tables.py`. Do not edit it by hand: change the generator and run it from the repository root with Python 3.14 (Unicode 16.0.0; the script checks):

```bash
python3 tool/generate_text_key_tables.py > lib/core/database/text_key_tables.dart
dart format lib/core/database/text_key_tables.dart
```

If the generated output changes key results, bump `textKeysVersion` as above.

### Instances and media controls

- **Debug builds run side by side** with an installed or running Kanaru, so `flutter run` always starts. **Profile and Release builds are single-instance**: launching again only brings the running window forward. As a consequence, `flutter run --profile` / `--release` does not open while a Release build is running; close it first.
- **Hot restart crashes the app** (SIGSEGV inside libmpv while `media_kit` tears down the previous player). This is a `media_kit` issue that only affects development. Hot reload (`r`) is fine; after changing startup or provider initialization code, quit and run again.
- **Known limitation, Wayland focus**: on compositors that require xdg-activation (verified on niri), launching Kanaru a second time or calling MPRIS `Raise` does not bring the window forward or mark it urgent. GTK 3 gets no activation token to present with. Tracked as SYS-15 in [features](features.md).
- **MPRIS**: the app registers `org.mpris.MediaPlayer2.kanaru` on the session bus. A second instance (e.g. Debug next to Release) falls back to `org.mpris.MediaPlayer2.kanaru.instance<pid>` and logs it. Try it from the dev shell, which ships `playerctl`:

```bash
playerctl -l                          # kanaru (and kanaru.instance<pid> if two run)
playerctl -p kanaru status
playerctl -p kanaru play-pause | next | previous | stop
playerctl -p kanaru position 30       # absolute; "10+" / "10-" for relative
playerctl -p kanaru metadata --follow
```

### Logs

Kanaru writes its log to `$XDG_CACHE_HOME/kanaru/logs/kanaru.log` (`~/.cache/kanaru/logs` when `XDG_CACHE_HOME` is unset or not an absolute path). Debug builds also print every line to the console.

- **Rotation**: each start moves `kanaru.log` to `kanaru.log.1` and so on, keeping 5 files (`kanaru.log` + `.1`–`.4`). A file that grows past 10 MB during a session rotates right away and starts with the session header again. If `~/.cache/kanaru` is deleted while Kanaru runs, the directory and lock are made again at the next rotation.
- **Several instances**: the first one holds a lock on `kanaru.lock` and owns `kanaru.log`. Another instance running at the same time (e.g. `flutter run` next to an installed build) writes `kanaru-<pid>.log` instead and rotates nothing else (at 10 MB it moves its file to `kanaru-<pid>.log.1`). The owner keeps the files of the 4 newest pids. Anything that reads the log directory must skip `kanaru.lock`: closing a handle to it drops the lock.
- **Level**: Debug logs everything (`ALL`), Profile/Release log `INFO` and above. Override with `KANARU_LOG_LEVEL` using a `package:logging` level name, in any case (`FINE`, `info`, `warning`…). An unknown value keeps the default and logs a warning. The first line of each session shows the version, OS, pid and level. mpv messages are always forwarded from `warn` up, whatever the level.
- **Version**: set it for release builds with `--dart-define=KANARU_VERSION=<version>` (otherwise `dev`).
- Uncaught errors (framework, async, providers) are logged with their stack trace and do not stop the app. They are written whatever `KANARU_LOG_LEVEL` says, and Release builds do not print them to the console (the journal). When the log file cannot be opened, warnings and errors go to stderr instead.
- Credentials in URLs, JSON, `key=value` pairs and auth headers are masked as a safety net (also when percent-encoded); still keep them out of log messages. A record is cut at 16 KB.

```bash
tail -f ~/.cache/kanaru/logs/kanaru.log
KC=$(mktemp -d) && KANARU_LOG_LEVEL=fine XDG_CACHE_HOME=$KC flutter run -d linux   # throwaway log dir
```

### Tests & lints

```bash
flutter analyze
flutter test
cargo test --locked --manifest-path rust/Cargo.toml
cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings
```

#### Benchmarks

The database benchmarks run 100k-track libraries in a file database; the Rust one times a scan with covers on real audio files. All are skipped unless `KANARU_BENCH=1` is set.

| File | What it times | Run |
|---|---|---|
| `test/core/database/browse_queries_benchmark_test.dart` | Browse SQL (median of 5 runs after one warm-up), a scan with the Songs list or an album page open, and reads during a scan | `KANARU_BENCH=1 flutter test test/core/database/browse_queries_benchmark_test.dart` |
| `test/core/database/library_keys_backfill_benchmark_test.dart` | Key backfill through the background isolate path the app uses, plus in-place chunk times | `KANARU_BENCH=1 flutter test test/core/database/library_keys_backfill_benchmark_test.dart` |
| `rust/tests/scan_covers_bench.rs` | A scan with covers stage by stage (tags, picture load, hash, decode+resize+encode, write), the cover pool as the app calls it, and the tag batch. Needs `KANARU_BENCH_LIST` (a file with one audio path per line) and `XDG_CACHE_HOME` under `/tmp/`; `KANARU_BENCH_SECTION=tags\|serial\|pool` runs one part (one process per part gives its peak memory) | `KANARU_BENCH=1 KANARU_BENCH_LIST=files.txt XDG_CACHE_HOME=/tmp/kanaru-bench-cache cargo test --release --manifest-path rust/Cargo.toml --test scan_covers_bench -- --nocapture` |

For query timings only, add `--plain-name 'browse queries'` to the first command.

Timings are printed to the console. They depend on the machine and the repo keeps no reference numbers, so compare runs on the same machine.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `CMake Error: ... gtk+-3.0 not found` | Install the GTK 3 dev package (`libgtk-3-dev` / `gtk3-devel`). |
| `libmpv.so: cannot open shared object file` at runtime | Install the mpv runtime package (`mpv` / `libmpv2`). On Nix, run inside the dev shell. |
| App aborts with `No GSettings schemas are installed on the system` when opening files | GTK's file chooser needs compiled schemas. Distros ship them with GTK 3; on Nix, run inside the dev shell, which adds them to `XDG_DATA_DIRS`. |
| No sound, or mpv errors about locale | Make sure your locale is valid (`locale` shows no errors). `media_kit` sets `LC_NUMERIC` itself. |
| `flutter_secure_storage` fails to read or write | A Secret Service provider must be running (GNOME Keyring, KWallet ≥ 5.97, or KeePassXC with Secret Service enabled). |
| `Unable to find libclang` during Rust codegen | Install `libclang-dev` / `clang-devel` and set `LIBCLANG_PATH`. |

## End-user runtime dependencies

No packages exist yet (see [Deployment guide](deployment-guide.md)). A build from `make build` needs libmpv, GTK 3 and SQLite at runtime. Once packaging lands (planned, PKG-01..05 in `docs/features.md`), users of release builds will not need any of the above: AppImage and Flatpak builds will bundle libmpv, `.deb` and `.rpm` packages will declare `libmpv2` as a dependency.

## AI agent tooling (optional)

`.mcp.json` registers the official Dart/Flutter MCP server through `tool/dart-mcp.sh`. The script uses `dart` from your PATH, or the Nix dev shell if `dart` is not on PATH. MCP-capable agents such as Claude Code then get analyze, format, tests, pub, hot reload and widget inspection.
