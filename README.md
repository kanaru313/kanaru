<div align="center">

# Kanaru

**Plays & manages your music library — wherever it lives.**

Beautiful & juicy Material Design 3 music player for GNU/Linux, Windows, macOS, Android & iOS.
Local files first, then your own cloud: Subsonic/Navidrome, WebDAV, S3-compatible storage, Google Drive.

> 🚧 Early development — nothing is usable yet.

</div>

---

## Why Kanaru?

Most desktop music players only understand local folders. Most cloud music apps only understand one service.
Kanaru treats every source the same way: your Navidrome server, a Nextcloud folder, an R2 bucket and `~/Music`
all merge into **one library**, with offline caching so it keeps playing when the network doesn't.

## Features

### Core (offline-first)

- 🎵 Plays almost anything — MP3, FLAC, ALAC, AAC/M4A, OGG Vorbis, Opus, WAV, APE, WavPack… (powered by libmpv)
- 📚 Library browsing by albums, artists, album artists, genres, years, folders
- 🔍 Fast full-text search
- 📝 Playlists, queue management, shuffle / repeat
- 🎧 Gapless playback, ReplayGain
- 🎨 Material You — dynamic colors extracted from album art, light/dark themes
- 🖥️ Native media controls — MPRIS (Linux), SMTC (Windows), Now Playing (macOS), notification/lock screen (Android/iOS)
- 🔒 Works fully offline, no account required, no telemetry

### Remote sources (planned)

| Source                                                                  | Auth                        | Notes                                                            |
| ----------------------------------------------------------------------- | --------------------------- | ---------------------------------------------------------------- |
| **Subsonic / OpenSubsonic** (Navidrome, Gonic, Airsonic…)               | Username + password / token | Server-side metadata, artwork & transcoding — no scanning needed |
| **WebDAV** (Nextcloud, ownCloud, Synology, rclone…)                     | Basic / Digest              |                                                                  |
| **S3-compatible** (AWS S3, Cloudflare R2, Backblaze B2, MinIO, Wasabi…) | Access key + secret         | Custom endpoint, path-style or virtual-host                      |
| **SFTP**                                                                | Password / key              |                                                                  |
| **Google Drive**                                                        | OAuth 2.0                   | Bring-your-own client ID supported                               |

- ⚡ Remote tag reading via HTTP range requests — no full downloads to index
- 🔄 Incremental rescans (ETag / mtime / Drive Changes API)
- 💾 Transparent disk cache + "download for offline"

### Premium (planned)

Kanaru is open source and fully usable for free. Some extra features will be available with a premium license
to support development. The exact list is not final.

## Architecture

```
┌──────────────── UI (Flutter + Material 3) ────────────────┐
│ Library · Now Playing · Queue · Playlists · Sources       │
└──────────────────────────┬────────────────────────────────┘
                 Riverpod (state) · go_router
┌──────────────────────────┴────────────────────────────────┐
│ Library service    │ Player service    │ Indexer          │
│ (drift / SQLite)   │ (media_kit/mpv)   │ (scan + tags)    │
└─────────┬──────────┴─────────┬─────────┴────────┬─────────┘
          │      Local HTTP proxy (127.0.0.1)      │
          │      auth · token refresh · range ·    │
          │      LRU disk cache · offline          │
┌─────────┴────────────────────────────────────────┴────────┐
│ StorageProvider                                           │
│  Local │ Subsonic │ WebDAV │ S3 │ SFTP │ Google Drive     │
└───────────────────────────────────────────────────────────┘
```

The player never talks to a remote service directly. It plays `http://127.0.0.1:<port>/track/<id>` and the
local proxy handles authentication, request signing, token refresh, range requests and caching. Adding a new
source means implementing one `StorageProvider` interface.

### Tech stack

| Area            | Choice                                                                  |
| --------------- | ----------------------------------------------------------------------- |
| UI              | Flutter, Material Design 3, `dynamic_color`, `material_color_utilities` |
| State / routing | Riverpod, go_router                                                     |
| Playback        | `media_kit` (libmpv)                                                    |
| Database        | `drift` (SQLite + FTS5)                                                 |
| Tag reading     | `lofty` (Rust) via `flutter_rust_bridge`                                |
| Media controls  | MPRIS (D-Bus), `smtc_windows`, `audio_service`                          |
| Credentials     | `flutter_secure_storage` (libsecret / Keychain / Keystore)              |
| Local proxy     | `shelf`                                                                 |

## Roadmap

Detailed feature list with IDs, priorities and acceptance criteria: **[docs/features.md](docs/features.md)**.

**Phase 0 — Foundation** · Linux

- [x] Project scaffold, M3 theme, CI
- [x] Play a local file with `media_kit`
- [x] MPRIS integration

**Phase 1 — Offline local player** · Linux

- [ ] Folder scanning & tag reading, embedded / folder artwork
- [ ] Library database & browsing (albums, artists, genres, folders)
- [ ] Now Playing, mini player, queue, shuffle / repeat
- [ ] Search, playlists (incl. M3U import/export)
- [ ] Gapless, ReplayGain
- [ ] Dynamic color from album art
- [ ] Packaging: AppImage, Flatpak, `.deb`

**Phase 2 — More platforms**

- [ ] Windows, macOS
- [ ] Android, iOS (background playback, media session)

**Phase 3 — Remote sources & streaming**

- [ ] `StorageProvider` abstraction + local proxy + disk cache
- [ ] Subsonic / OpenSubsonic (Navidrome)
- [ ] WebDAV
- [ ] S3-compatible
- [ ] SFTP
- [ ] Download for offline, online/offline indicators
- [ ] Google Drive

**Phase 4 — Juicy**

- [ ] Lyrics: `.lrc`, embedded, LRCLIB — synced lyrics view
- [ ] Waveform seekbar, visualizer, polished transitions
- [ ] Equalizer, crossfade, sleep timer
- [ ] Listening stats, Last.fm / ListenBrainz scrobbling
- [ ] Sync playlists & settings across devices

## Building

See **[docs/development.md](docs/development.md)** for full setup instructions (Nix, Debian/Ubuntu, Fedora, Arch).

```bash
# Nix users
nix develop            # or: direnv allow

flutter pub get
flutter run -d linux
```

## Contributing

Issues and ideas are welcome. Contribution guidelines (and a CLA, if needed for dual licensing) will be added
before accepting pull requests.

## License

Kanaru is free software, licensed under the [GNU General Public License v3.0 or later](LICENSE).
