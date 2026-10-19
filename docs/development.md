# Development setup

Kanaru currently targets **GNU/Linux** first. Windows, macOS, Android and iOS instructions will be added in phase 2.

## What you need

| Tool | Version | Why |
|---|---|---|
| Flutter (stable) | ≥ 3.47 (Dart ≥ 3.13) | App framework |
| Clang, CMake, Ninja, pkg-config | any recent | Flutter Linux desktop toolchain |
| GTK 3 (dev headers) | ≥ 3.24 | Flutter Linux embedder |
| libmpv (dev headers) | ≥ 0.36 | Audio playback (`media_kit`) |
| libsecret, jsoncpp (dev headers) | any recent | Credential storage (`flutter_secure_storage`) |
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

### Code generation

Run code generation again after changing drift tables, Riverpod annotations or Rust APIs:

```bash
# Dart (drift, riverpod, freezed…)
dart run build_runner build --delete-conflicting-outputs

# Rust bindings (after changing rust/src/api)
RUSTC_BOOTSTRAP=1 flutter_rust_bridge_codegen generate

# After bumping schemaVersion in the library database: new migration step + test
dart run drift_dev make-migrations
```

Notes on the Rust side:

- **Pinned codegen**: the Dart `flutter_rust_bridge` package, the crate and `flutter_rust_bridge_codegen` must all be 2.13.0 (`flutter_rust_bridge_codegen --version`). The dev shell provides the codegen binary; outside Nix, `cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked`.
- **`RUSTC_BOOTSTRAP=1`**: codegen runs `cargo expand`, which needs nightly features. The variable lets the stable toolchain do it. The dev shell ships `cargo-expand`; elsewhere `cargo install cargo-expand`.
- **`rustup` shim (Nix only)**: the build glue (cargokit) calls `rustup toolchain list`, `rustup target list --installed` and `rustup run <toolchain> cargo`. Nix provides one fixed toolchain and no rustup, so the dev shell has a tiny `rustup` script that answers exactly those three calls and fails on anything else. Without it `flutter run` fails while building the Rust crate. Cargokit looks for `~/.cargo/bin/rustup` before `PATH`, so a real rustup install bypasses the shim.
- **Rust builds** happen inside `flutter run` / `flutter build` (cargokit builds the crate in debug for debug app builds and in release otherwise). The first build is slow, and each git worktree has its own `rust/` build output.
- **Tests**: `cargo test --locked --manifest-path rust/Cargo.toml` (`--locked` fails if `Cargo.lock` is out of date).

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

Users of release builds do **not** need any of the above. AppImage and Flatpak builds bundle libmpv. `.deb` and `.rpm` packages declare `libmpv2` and `libsecret-1-0` as dependencies.

## AI agent tooling (optional)

`.mcp.json` registers the official Dart/Flutter MCP server through `tool/dart-mcp.sh`. The script uses `dart` from your PATH, or the Nix dev shell if `dart` is not on PATH. MCP-capable agents such as Claude Code then get analyze, format, tests, pub, hot reload and widget inspection.
