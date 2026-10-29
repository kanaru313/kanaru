<div align="center">

# Kanaru

**Plays & manages your music library — wherever it lives.**

Beautiful & juicy Material Design 3 music player for GNU/Linux, Windows, macOS, Android & iOS.
Local files first, then your own cloud: Subsonic/Navidrome, WebDAV, S3-compatible storage, Google Drive.

> 🚧 Early development — the Linux local player works; packages and the rest of Phase 1 are in progress.

</div>

---

## Why Kanaru?

Most desktop music players only understand local folders. Most cloud music apps only understand one service.
Kanaru treats every source the same way: your Navidrome server, a Nextcloud folder, an R2 bucket and `~/Music`
all merge into **one library**, with offline caching so it keeps playing when the network doesn't.

## Features

### Core (offline-first)

- 🎵 Plays almost anything — MP3, FLAC, ALAC, AAC/M4A, OGG Vorbis, Opus, WAV, APE, WavPack… (powered by libmpv)
- 📚 Library browsing by albums, artists, album artists, genres, years, folders *(albums, artists, genres, folders and songs so far)*
- 🔍 Full-text search of songs, albums and artists, ignoring accents: typo correction, search history, field syntax (`artist:`, `year:2010-2015`, `format:flac`, `language:vi`), a field picker, and filter boxes on album, artist, genre, playlist, queue and History pages
- 📝 Playlists *(Phase 1)*, queue management, shuffle / repeat
- 🎧 Gapless playback, ReplayGain *(Phase 1)*
- 🎨 Material You — light/dark themes and system accent; dynamic colors from album art *(Phase 1)*
- 🖥️ Native media controls — MPRIS (Linux), SMTC (Windows), Now Playing (macOS), notification/lock screen (Android/iOS)
- 🔒 Works fully offline, no account required, no telemetry; the only network use is opt-in (see [Privacy and network](#privacy-and-network))

### Lyrics

- 📝 Lyrics from `.lrc` files next to the song and from the file's tags (embedded lyrics read with lofty), with a synced view that follows the line being sung and seeks on click
- 🌐 Online lyrics from [LRCLIB](https://lrclib.net), **opt-in**: off until you accept a notice. Search by hand from the song menu (*Find lyrics online…*), or let Kanaru look up songs without lyrics while Now Playing is open. Pick the right match in *Choose lyrics*; a pick is kept in your library and never written to a file next to the song

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

> The diagram is the target design. The library, player and indexer exist today; the storage providers and the proxy are planned. See [docs/system-architecture.md](docs/system-architecture.md) for what is built.

The player never talks to a remote service directly. It plays `http://127.0.0.1:<port>/track/<id>` and the
local proxy handles authentication, request signing, token refresh, range requests and caching. Adding a new
source means implementing one `StorageProvider` interface.

### Tech stack

| Area            | Choice                                                                  |
| --------------- | ----------------------------------------------------------------------- |
| UI              | Flutter, Material Design 3, `dynamic_color`, cover colors via `material-colors` (Rust) |
| State / routing | Riverpod, go_router                                                     |
| Playback        | `media_kit` (libmpv)                                                    |
| Database        | `drift` (SQLite, FTS5 index)                                            |
| Tag reading     | `lofty` (Rust) via `flutter_rust_bridge`                                |
| Media controls  | MPRIS (D-Bus, built in-house); `smtc_windows`, `audio_service` planned  |
| Credentials     | `flutter_secure_storage` (libsecret / Keychain / Keystore), planned     |
| Local proxy     | `shelf`, planned                                                        |

## Privacy and network

Kanaru sends nothing unless you turn a network feature on. Each feature asks before its first request.

| Feature | Sent to | What is sent | When |
|---|---|---|---|
| Online lyrics (LRCLIB) | `lrclib.net` | `/api/get`: title, primary artist, duration rounded to whole seconds (never the album). Automatic `/api/search`: the title, plus the primary artist when the song has one artist. Manual search: the text you typed. The request carries `User-Agent: Kanaru/<version>` (+ repository URL) | Automatic lookup: only while Now Playing is open, with *Find lyrics automatically* on and accepted. Manual search: only when you search |
| Lyrics translation | Google Translate or DeepL (the service you chose) | The lyric lines of the playing song, and your DeepL key to DeepL | Only after you accept that service's notice, and only while a Now Playing widget shows the song |

Never sent for lyrics: file paths, file names or device information.

Writing files: Kanaru writes a lyrics file only when you choose *Save lyrics*, and only inside your library folders. It writes `<song name>.lrc` next to the song. If a lyrics file is already there, Kanaru asks first, and the old file is moved to the trash, never deleted. Your picks and choices are otherwise kept in the library database. *Clear saved lyrics* in Settings removes the stored lyrics, your choices and your rejected matches; it never touches `.lrc` files.

No telemetry, no analytics, no account.

## Roadmap

Detailed feature list with IDs, priorities and acceptance criteria: **[docs/features.md](docs/features.md)**. Checked items are on `main`; partially done items stay unchecked and say what is open. Status snapshot: [docs/project-roadmap.md](docs/project-roadmap.md).

**Phase 0 — Foundation** · Linux

- [x] Project scaffold, M3 theme
- [x] Play a local file with `media_kit`
- [x] MPRIS integration
- [ ] CI (no `.github/` workflows yet)

**Phase 1 — Offline local player** · Linux

- [x] Folder scanning & tag reading, embedded / folder artwork
- [ ] Library database & browsing: albums, artists, genres, folders, songs done
- [ ] Now Playing, mini player, queue, shuffle / repeat: shipped, with queue history on the History page; hero transition open
- [x] Full-text search over songs, albums and artists: typo correction, search history, field syntax, field picker, shortcuts and in-page filters; search over lyrics still open
- [x] Playlists (incl. M3U): create, rename, delete, add, remove and reorder, Favorites, M3U import and export, save the queue as a playlist
- [ ] Gapless, ReplayGain: gapless configured, not verified; ReplayGain done, with output device choice in Settings > Advanced
- [x] Dynamic color from album art
- [ ] Packaging: AppImage done; Flatpak, `.deb` not started
- [ ] Before the first release: collapse the database schema history into v1

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

- [ ] Lyrics: `.lrc`, embedded, LRCLIB — synced lyrics view: `.lrc`, embedded, online lookup with *Choose lyrics*, pins, saved lyrics and the synced view are done; open: several lyrics sources and a source picker, a narrow-window *Choose lyrics* dialog, the provider plugin runtime, manual lyrics entry, time offset
- [x] Lyrics translation (Google or DeepL): header button and menu in Now Playing, `T` to toggle; the first use of a service asks before lyrics are sent. Settings > Advanced: service, DeepL API key (kept in the system keyring, checked with DeepL before it is saved, quota shown), default language, and the saved translations (count, size, clear)
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

## Documentation

| Doc | For |
| --- | --- |
| [Project overview & PDR](docs/project-overview-pdr.md) | Vision, priorities, requirements, status |
| [Codebase summary](docs/codebase-summary.md) | Directory map, entry points, generated code |
| [Code standards](docs/code-standards.md) | Layering, Riverpod, conventions, testing |
| [System architecture](docs/system-architecture.md) | Startup, scan, playback, MPRIS, storage, schema |
| [Design guidelines](docs/design-guidelines.md) | Breakpoints, shell, player, motion, accessibility |
| [Development setup](docs/development.md) | Toolchain, codegen, logs, troubleshooting |
| [Deployment guide](docs/deployment-guide.md) | Release build, runtime needs, data locations, packaging plan |
| [Roadmap](docs/project-roadmap.md) | Phases 0 to 4 with actual status |
| [Features](docs/features.md) | Requirement IDs, priorities, acceptance criteria (Vietnamese) |

## Contributing

Issues and ideas are welcome. Read [docs/code-standards.md](docs/code-standards.md) first. Contribution guidelines (and a CLA, if needed for dual licensing) will be added
before accepting pull requests.

## License

Kanaru is free software, licensed under the [GNU General Public License v3.0 or later](LICENSE).
