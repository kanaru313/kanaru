# AppImage packaging

`make appimage` writes `dist/Kanaru-<version>-x86_64.AppImage`. Everything is built inside
`debian:bookworm` (glibc 2.36) by `Dockerfile`; nothing from the host build tree is used.
Needs Docker with BuildKit (23+) and network access.

| File | Purpose |
|---|---|
| `Dockerfile` | Stages `libmpv-build`, `app-build` (Flutter + Rust), `package`, `export` (scratch, holds only the AppImage). |
| `Dockerfile.dockerignore` | Allowlist of the build context. |
| `build-libmpv.sh` | Audio-only mpv/FFmpeg/libplacebo build into `/opt/libmpv`. |
| `check_libmpv_formats.py` | Decodes sample files through the built libmpv. |
| `assemble-appdir.sh` | Builds AppDir, adds libmpv and libass, asserts the layout, runs appimagetool. |
| `AppRun` | Points `LIBMPV_LIBRARY_PATH` at the bundled libmpv and starts the app. |

GTK, GLib, libstdc++, libpulse and libasound come from the host.

## Pins

Every download is checked against a sha256 in `Dockerfile` (`ARG`s): base image `debian:bookworm-20261020`,
Flutter 3.47.4 (engine revision asserted to match the Nix dev shell), rustup-init 1.29.2,
appimagetool 1.9.1, type2 runtime `20251108`. To bump one, change the
tag and sha256 together (`sha256sum` of the release asset). Not pinned: Debian apt packages and the Rust
`stable` toolchain (cargokit accepts channel names only); both are frozen by Docker layer caching.

## Cache

BuildKit keeps the libmpv and toolchain layers, so a Dart-only change rebuilds just the app and package stages.
`docker builder prune` frees the cache (tens of GB over time).
