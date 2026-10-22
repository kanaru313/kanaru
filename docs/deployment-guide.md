# Deployment guide

How Kanaru is built, run and reset today, and what is still missing before it can be released. As of 2026-10-22 there is **no release process**: no tags, no CI workflow, and no installer. The artifacts are the Flutter Linux bundle (`make build`) and one package, an x86_64 AppImage (`make appimage`).

Dev setup (toolchain, distro packages, codegen) is in [development.md](./development.md). This page covers building for use, runtime requirements and data locations.

## Status

| Item | State | Evidence |
|---|---|---|
| Release build target | Works | `Makefile` target `build` |
| AppImage (x86_64) | Works | `make appimage`; recipe in `packaging/appimage/` |
| Version injection | Works in `make appimage`; `make build` does not pass it | `KANARU_VERSION` read in `lib/core/logging/app_logging.dart` |
| CI | **Not started** | No `.github/` directory |
| Packages besides AppImage (Flatpak, deb, rpm, AUR, Nix) | **Not started** | No manifests or recipes; `flake.nix` has only `devShells.default` |
| Desktop entry and icon | Works in the AppImage | `packaging/linux/` (`.desktop`, metainfo, icons). The plain bundle has none |
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
| `build/linux/<x64 or arm64>/release/bundle/lib/` | Flutter engine, Rust tag reader and SQLite libraries. **No libmpv**: the bundle loads the system libmpv |
| `build/linux/<x64 or arm64>/release/bundle/data/` | Flutter assets, ICU data, native assets |

Run it from the bundle directory:

```bash
./build/linux/x64/release/bundle/kanaru
```

Install by copying the bundle directory (for example to `~/.local/opt/kanaru`). The bundle has no desktop entry and no icon, so the app will not appear in launchers or in "Open with" menus. The [AppImage](#appimage) has both.

### Build-time network

`make build` downloads two things:

- `media_kit_libs_linux` fetches the mimalloc 2.1.2 source archive and checks its MD5. It does not download libmpv: libmpv must be installed on the build and run machine.
- The `sqlite3` package build hook may download a prebuilt `libsqlite3.so`.

Rust is built by cargokit inside `flutter build`. The first build is slow. Use `--locked` for the crate; see [development.md](./development.md#code-generation).

`make appimage` downloads its inputs inside Docker. Each has a sha256 or commit check, listed in `packaging/appimage/Dockerfile` and `packaging/appimage/build-libmpv.sh`: FFmpeg, mpv, libplacebo, the Flutter SDK, rustup-init, appimagetool and the AppImage runtime. Debian packages, the Rust `stable` toolchain and the Flutter engine artifacts from `flutter precache` are not hash-pinned.

## AppImage

One file for x86_64 Linux: `dist/Kanaru-<version>-x86_64.AppImage`. It bundles the Flutter app, an audio-only libmpv (with libass) and the LGPL notices. GTK 3, Mesa, glibc and the audio libraries come from the host. The recipe, pins and cache notes are in [packaging/appimage/README.md](../packaging/appimage/README.md).

### Build

```bash
make appimage
```

| Item | Value |
|---|---|
| Needs | Docker 23+ with BuildKit, network access |
| Build environment | `debian:bookworm` (glibc 2.36) from `packaging/appimage/Dockerfile`. Nothing from the host build tree is used |
| Output | `dist/Kanaru-<version>-x86_64.AppImage`. The version comes from `pubspec.yaml` without the `+build` suffix |
| Time, cold (`--no-cache`, 8 cores) | about 17.5 min (measured 17 min 34 s) |
| Time, nothing changed | about 4 s (all steps cached) |
| Time, new commit without app changes | about 15 s |
| Disk | Build cache size not measured. It grows over time; `docker builder prune` frees it |

### Measured results

Measured on the first AppImage build (2026-10-22). The full verification log is kept with the project plans, not in this repo.

| Item | Value |
|---|---|
| AppImage size | 16,370,168 bytes (15.6 MiB). NFR-04 limit: 60 MiB |
| Uncompressed AppDir | 44,854,336 bytes |
| Highest glibc symbol | `GLIBC_2.35` (floor set by the build: 2.36) |
| Highest libstdc++ symbol | `GLIBCXX_3.4.29` (libstdc++ from GCC 11+ on the host) |

Where it was run:

| Environment | Result |
|---|---|
| Debian 12 container (Xvfb, no GPU) | Starts. 20/20 format files decode, with `ao=null` and with PulseAudio (null sink) |
| Debian 12 with `libmpv-dev` installed | Same. The bundled libmpv is the one loaded |
| Ubuntu 24.04 container | Same as Debian 12 |
| Fedora (latest) container | Same as Debian 12 |
| Arch (latest) container, system `mpv` installed | Same. The bundled libmpv is loaded, not the system one |
| NixOS desktop (real GUI, PipeWire), started with `appimage-run` | Window and MPRIS work. 20/20 formats decode with real audio output |
| Debian 12 without `libpulse0` and `libasound2` | Starts in library-only mode. No playback |

The 20 format files cover MP3, FLAC, M4A (AAC and ALAC), AAC (ADTS), ALAC, OGG Vorbis, Opus (OGA and Opus), WAV, AIFF, APE, WavPack, DSF and DFF, plus MP3, FLAC and M4A with embedded cover art.

These are decode checks run through libmpv, not listening tests. Audible playback through the UI was not checked.

Not tested: other versions of these distros, Ubuntu 22.04 and older (glibc 2.35, below the documented floor), Wayland compositors other than niri, and KDE or GNOME desktops.

### Host requirements

| Needed on the host | Why | Debian 12 package |
|---|---|---|
| glibc 2.36 or newer | Floor for the build. The binary needs 2.35 | (part of the OS) |
| libstdc++ with `GLIBCXX_3.4.29` (GCC 11+) | C++ runtime, not bundled | `libstdc++6` |
| GTK 3 | Flutter GTK embedder, folder picker | `libgtk-3-0` |
| `libGLESv2.so.2` and EGL (glvnd, Mesa) | The engine exits at start without `libGLESv2.so.2` | `libgles2` (Fedora: `mesa-libGLES`) |
| `libpulse.so.0`, `libasound.so.2` | Audio output. Without them the app starts with no playback | `libpulse0`, `libasound2` |
| `libfontconfig`, `libfreetype`, `libharfbuzz`, `libfribidi` | Used by the bundled libass | installed with GTK in most desktops |
| FUSE: `/dev/fuse` and `fusermount3` (or `fusermount`) | Mounting the AppImage. Not needed with `--appimage-extract-and-run` | `fuse3` |

Package names are for Debian 12; other distros name them differently.

### Run

```bash
./dist/Kanaru-0.1.0-x86_64.AppImage
```

- No FUSE on the host (containers, minimal systems): `./Kanaru-0.1.0-x86_64.AppImage --appimage-extract-and-run`.
- NixOS: `appimage-run ./Kanaru-0.1.0-x86_64.AppImage`.

### Desktop integration

The AppImage contains `usr/share/applications/io.github.kanaru313.kanaru.desktop` with the audio MIME types, and the icons. Its `Exec=kanaru %U` line refers to a `kanaru` command that is not on `PATH`, so the launcher entry must point at the AppImage. AppImageLauncher and Gear Lever rewrite `Exec=` when they install an AppImage (not tested here). To do it by hand:

```bash
APP="$HOME/Applications/Kanaru-0.1.0-x86_64.AppImage"
mkdir -p "$HOME/Applications" "$HOME/.local/share/applications" "$HOME/.local/share/icons"
install -m755 dist/Kanaru-0.1.0-x86_64.AppImage "$APP"
X=$(mktemp -d)
(cd "$X" && "$APP" --appimage-extract >/dev/null)
cp -r "$X/squashfs-root/usr/share/icons/." "$HOME/.local/share/icons/"
sed "s|^Exec=.*|Exec=\"$APP\" %U|" \
  "$X/squashfs-root/usr/share/applications/io.github.kanaru313.kanaru.desktop" \
  > "$HOME/.local/share/applications/io.github.kanaru313.kanaru.desktop"
rm -rf "$X"
update-desktop-database "$HOME/.local/share/applications"
```

### Limits

| Limit | Status |
|---|---|
| "Open with Kanaru" starts or raises the app but does not play the file | Until SYS-08 (command-line file arguments) |
| Second launch does not raise the window under niri | SYS-15 |
| Network streams (`http`, `https`) | Not built in. FFmpeg is configured with `--disable-network` and only the `file` protocol |
| Video | Not supported. The libmpv build has audio decoders only |
| Audio output | Needs `libpulse.so.0` and `libasound.so.2` on the host |
| Log line `SEVERE mpv: ... property not found _setProperty(osc, 1)` on every start | Harmless. The bundled libmpv has no Lua, so the `osc` option does not exist |

### Licensing

The AppImage ships these builds. Versions and build flags are in `usr/share/licenses/SOURCES.txt`:

| Component | Version | License | Source |
|---|---|---|---|
| FFmpeg | 8.1.3 | LGPL-2.1+ (no `--enable-gpl`, `--enable-version3`, `--enable-nonfree`) | `ffmpeg.org` tarball, sha256 in `SOURCES.txt` |
| mpv (libmpv) | 0.41.0 (`-Dgpl=false`) | LGPL-2.1+ | git tag `v0.41.0`, commit in `SOURCES.txt` |
| libplacebo | 6.338.2 (linked statically into libmpv) | LGPL-2.1+ | git tag `v6.338.2`, commit in `SOURCES.txt` |
| libass | Debian 12 `libass9` package | ISC | Debian sources, recorded in `SOURCES.txt` |

License texts are in `usr/share/licenses/` inside the AppImage, with the Kanaru `LICENSE` (GPL-3.0-or-later). Not in the AppImage yet: license notices for the Rust crates linked into the app library and for mimalloc.

## Runtime requirements

| Requirement | Release bundle | AppImage | Notes |
|---|---|---|---|
| Flutter engine, ICU, assets | Bundled | Bundled | |
| libmpv | System | Bundled (audio-only build) | Bundle: install the distro's libmpv runtime (`libmpv.so.2`). Any libmpv load failure logs `Audio engine failed to initialise` |
| Rust tag reader | Bundled | Bundled | Shared library built by cargokit from `rust/`, bundled through `rust_builder` |
| SQLite | Bundled | Bundled | Library from the `sqlite3` package build hook. `make reset-library` also needs the `sqlite3` CLI (see [Reset targets](#reset-targets)) |
| GTK 3 | System | System | Required by the Flutter Linux embedder |
| OpenGL ES and EGL drivers | System | System | `libGLESv2.so.2` is required (see [Host requirements](#host-requirements)) |
| libpulse, libasound | System | System | Audio output |
| GSettings schemas (GTK) | System | System | Needed by GTK file pickers (folder picker). Distros ship them with GTK 3 |
| glibc | Build host | 2.36 or newer | |
| D-Bus session bus | Optional | Optional | Needed for MPRIS. The app runs without it, with no media controls |
| Secret Service (libsecret) | Not needed yet | Not needed yet | No credential storage in the code yet. Needed once remote sources land (PRIV-04) |

Not linked today: `libsecret`, `jsoncpp`. `development.md` lists them as build dependencies for `flutter_secure_storage`, which is not in `pubspec.yaml` yet.

Desktop environments: the bundle is GTK 3 and talks to the compositor through the normal X11 or Wayland path. Known limit on compositors that need xdg-activation (verified on niri): a second launch or MPRIS `Raise` does not bring the window forward (SYS-15).

## Environment variables

| Variable | Default | Effect |
|---|---|---|
| `KANARU_LOG_LEVEL` | `ALL` in Debug, `INFO` in Profile and Release | `package:logging` level name, any case. Unknown values keep the default and log a warning. |
| `XDG_CONFIG_HOME` | `~/.config` | Config directory parent. Relative or empty values are ignored. |
| `XDG_DATA_HOME` | `~/.local/share` | Data directory parent. |
| `XDG_CACHE_HOME` | `~/.cache` | Cache and log directory parent. |
| `KANARU_VERSION` (build-time define) | `dev` | Shown in the session header of the log. `make appimage` sets it from `pubspec.yaml`. |
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

Quit Kanaru first. `reset-covers` and `reset-all` are `Makefile` rules that run `rm -rf` on the paths shown. `reset-library` runs [packaging/dev/reset-library.sql](../packaging/dev/reset-library.sql) with the `sqlite3` CLI (from `PATH`, else from the Nix dev shell; non-Nix users need `sqlite3` 3.35+ with FTS5). It refuses to run while one of your processes has `library.db` open (it looks through `/proc/*/fd`, so other users' processes are not seen).

| Command | Removes | Keeps | Next start |
|---|---|---|---|
| `make reset-covers` | `cache/covers` | everything else | Covers read again on the next scan |
| `make reset-library` | Library folders, tracks, track artists and the search index inside `library.db`; `cache/covers` | Playlists, listen history and play counts, settings, session | Empty library: settings still record that onboarding is done, so the first-run folder picker does not show; add folders in Settings → Library. Old playlist entries and plays match again by path once the same files are scanned |
| `make reset-all` | `data`, `config`, `cache`: library, **playlists, listen history**, settings, playback session, covers, logs | nothing | Like a fresh install |
| `make logs` | nothing | everything | Follows `kanaru.log` |

`reset-library` lists its tables explicitly: when a table derived from the scan is added, update the SQL. For a throwaway dev schema change that is not worth migrating, use `make reset-all` (it also deletes playlists and listen history; see [development.md](./development.md#code-generation)).

## Single instance

Release and Profile builds are single-instance (GTK application uniqueness). A second launch activates the running window and exits. Debug builds run side by side, so `flutter run` always starts. This means a `flutter run --release` does not open while a release build is running.

## Packaging plan

Planned from [features.md section 18](./features.md). Only PKG-01 is done.

| ID | Target | Priority | Current state | Notes for the packaging work |
|---|---|---|---|---|
| PKG-01 | AppImage | P0 | Done (x86_64) | `make appimage`, recipe in `packaging/appimage/`. 15.6 MiB, GTK 3 from the host. See [AppImage](#appimage) |
| PKG-02 | Flatpak (Flathub) | P1 | Not started | Music folder access only through the file chooser portal. `flatpak-builder` is in the dev shell. |
| PKG-03 | `.deb` and `.rpm` | P1 | Not started | Declare `libmpv2`, `libsecret-1-0` (once needed) and GTK 3 as dependencies. |
| PKG-04 | AUR `kanaru-bin` | P2 | Not started | Depends on a published binary. |
| PKG-05 | Nix package | P2 | Not started | Only the dev shell is defined in `flake.nix`. |
| PKG-08 | Schema history collapse | P0 | Not started | Must happen before the first release; see [system-architecture.md](./system-architecture.md#7-library-database-schema). |

Before the first release: set the release version in `pubspec.yaml` and in the metainfo file, and decide on a tag format.

## Release checklist (manual until CI exists)

1. `git status` is clean on `main`; PRs for the release are merged.
2. `make check` passes (analyze, Dart tests, `cargo test --locked`).
3. `make gen` and `make gen-rust` leave no diff in generated files.
4. Bump `version:` in `pubspec.yaml` (currently `0.1.0+1`) and the `<release>` entry in `packaging/linux/io.github.kanaru313.kanaru.metainfo.xml` (currently `0.1.0`).
5. Build: `flutter build linux --release --dart-define=KANARU_VERSION=<version>` for the bundle, and `make appimage` for the AppImage.
6. Smoke test the bundle: `make reset-all` first; start; add a folder; scan; play; `playerctl -p kanaru status`; restart and check the queue is restored paused. Smoke test the AppImage on one non-NixOS distro container.
7. Check `~/.cache/kanaru/logs/kanaru.log` for errors from the run.
8. Tag the commit. Attach the AppImage and the bundle, plus the source for the LGPL libraries in the AppImage (FFmpeg tarball, mpv and libplacebo at the tags listed in `SOURCES.txt`). The tag format and changelog are not decided yet.

Steps 2 to 5 become CI jobs once workflows exist. The repo has no `.github/` directory today.

## Troubleshooting for installed builds

| Symptom | Check |
|---|---|
| Starts in library-only mode, play does nothing | Log line `Audio engine failed to initialise`. Bundle: install the system libmpv runtime (`libmpv.so.2`). AppImage: check the host has `libpulse.so.0` and `libasound.so.2`. Run with `KANARU_LOG_LEVEL=FINE` and attach the log. |
| AppImage exits at start, log shows `Couldn't open libGLESv2.so.2` | Install the GLES library (Debian and Ubuntu: `libgles2`; Fedora: `mesa-libGLES`). |
| AppImage: `fuse: failed to open /dev/fuse` or `fusermount: not found` | Run with `--appimage-extract-and-run`, or install `fuse3` and make sure `/dev/fuse` exists. |
| AppImage does not start on NixOS | Start it with `appimage-run`. |
| Log has `SEVERE mpv: ... _setProperty(osc, 1)` on every start | Harmless, see [Limits](#limits). |
| "Open with Kanaru" opens the app but does not play the file | Expected until SYS-08. |
| Folder picker does not open | GTK schemas missing: install the GTK 3 package of your distro. |
| Library empty after start | Check Settings → Library: the folders must exist (a missing one is struck through) and "Rescan when Kanaru opens" should be on. Press the rescan button. |
| Window does not come forward on second launch under niri | Known limit (SYS-15). |
| Anything else | Attach the log: `kanaru.log` and any `kanaru-<pid>.log` from the same time. Logs are not sent anywhere. |
