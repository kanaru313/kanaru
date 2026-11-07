# Source plugin API

A **source** plugin finds music on a website and gives the app a stream to play. It is a third kind of plugin next to *lyrics* and *translate*; everything the [Lyrics plugin API](./lyrics-plugin-api.md) says about the runtime, `fetch`, limits, `localStorage`, logs, packages and repositories applies to it too. This page lists only what is different. Architecture: [system-architecture-lyrics-plugins.md](./system-architecture-lyrics-plugins.md).

A source plugin has two scripts:

- `search.js` turns what the user typed into a list of items;
- `stream.js` turns the id of one item into an audio URL, when the user plays it.

## Manifest

```json
{
  "metadata": {
    "apiVersion": 1,
    "type": "source",
    "name": "YouTube",
    "version": 1,
    "hosts": ["www.youtube.com", "*.googlevideo.com"]
  },
  "script": { "search": "search.js", "stream": "stream.js" }
}
```

| Field | Rule |
|---|---|
| `metadata.type` | `"source"` (wire value in `lyrics_plugins.kind`: `source`) |
| `script.search`, `script.stream` | both required, plain file names inside `src/`. A missing `script.stream` is `invalidManifest` (`script.stream`); a name with no file in `src/` is `missingScript`. `script.lyrics` and `script.translate` are not read |
| `metadata.hosts` | as for other plugins, plus wildcard entries (below) |
| everything else | as in the [manifest table](./lyrics-plugin-api.md#plugin-package) of the lyrics API |

Older builds refuse `type: "source"` (`wrongType`) and wildcard hosts (`badHost`), so there is no `apiVersion` bump. The installed `plugin.json` is rewritten from the parsed manifest, `script.stream` included. There is no schema change: the kind is free text in the existing column.

## Hosts and the wildcard rule

A host entry is either a plain host name (the same rule as every plugin: `https`, a public DNS name with at least two labels) or `*.` followed by such a name.

- Wildcards are allowed **only in source plugin** manifests and catalog entries. In a lyrics or translate plugin, a wildcard entry is `badHost`.
- Any other `*` (`*`, `a.*.b.com`, `*foo.com`, `**.a.com`, `*.com`, `*.`) is `badHost`.
- At most 3 wildcard entries per plugin; a fourth is `badHost`.
- The base may not be a shared-hosting suffix under which anyone can register a name: `workers.dev`, `pages.dev`, `github.io`, `gitlab.io`, `netlify.app`, `vercel.app`, `herokuapp.com`, `appspot.com`, `web.app`, `firebaseapp.com`, `cloudfront.net`, `azurewebsites.net`, `blogspot.com`, `onrender.com`, `fly.dev`, `glitch.me`.
- A request host matches `*.<base>` when, lower-cased and not ending with `.`, it is exactly one label in front of `<base>`. The label is 1 to 63 of `[a-z0-9-]`, not starting or ending with `-`. So `*.googlevideo.com` allows `rr1---sn-x.googlevideo.com` but not `googlevideo.com`, `a.b.googlevideo.com` or `evilgooglevideo.com`. A request to any other host is `blockedHost` before a socket opens.
- There is no public suffix list, so a base such as `co.uk` passes. The plugin info page shows a wildcard as "any subdomain of X", and the user sees the hosts before installing.

The rule lives in one place, `lib/core/lyrics/online/plugin_host_patterns.dart`. The address rules (https only, public addresses only at connect time) are unchanged.

## `search.js`

Input (the first page, then the page after it):

```json
{ "query": "text the user typed" }
{ "query": "text the user typed", "next": "<the next of the previous page>" }
```

`query` may be a video or playlist URL, which the plugin may turn into one or more items.

Output:

```json
{
  "items": [
    { "id": "…", "title": "…", "artist": "…", "durationMs": 215000,
      "artworkUrl": "https://…", "webUrl": "https://…" }
  ],
  "next": "<string or null>"
}
```

| Field | What the app keeps |
|---|---|
| `items` | at most 200 items; an item that breaks a rule below is dropped (with a note in the log), the others stay |
| `id` | 1 to 200 characters, no control characters, not exactly `.` or `..` (they cannot travel in the proxy URL) |
| `title` | 1 to 300 characters after the usual name cleaning |
| `artist` | at most 200 characters, else none |
| `durationMs` | an integer from 1 to 86 400 000; anything else (a plugin's `0` included) means unknown |
| `artworkUrl`, `webUrl` | kept only as an absolute `https` URL of at most 2000 characters without user info, else none |
| `next` | a string of at most 8 KiB; a longer or empty one, or one equal to the `next` that was sent, means no next page. A page with no items and a `next` is allowed |

An output that is not an object with an `items` array, or whose `next` is neither a string nor null, is `invalidOutput`.

## `stream.js`

Input: `{ "id": "<item id>", "formats": ["progressive", "hls"] }`, plus `"fresh": true` when set. `formats` is always sent: the stream formats this build plays, in that order. A plugin that finds only an HLS playlist should return it only when `formats` holds `"hls"`; no `formats` (an older build) means return a progressive stream. `fresh` is left out when false; `true` asks the plugin to skip its own cache and resolve the stream again (the previous URL was refused).

Output:

```json
{
  "url": "https://rr1---sn-x.googlevideo.com/videoplayback?…",
  "headers": { "user-agent": "…" },
  "mimeType": "audio/webm",
  "bitrate": 128000,
  "expiresAtMs": 1790000000000
}
```

| Field | Rule |
|---|---|
| `url` | absolute `https`, at most 8 KiB, no explicit port (not even `:443`), no user info; else `invalidOutput`. Its host must be one the plugin declared (wildcards included): `stream()` does not check that, the stream proxy's resolver (`lib/core/sources/proxy/source_plugin_stream_resolver.dart`) does when the player first asks for the bytes, and refuses the item (`502`) otherwise |
| `headers` | absent means none; else an object of at most 20 string entries (anything else is `invalidOutput`), filtered like any plugin request header (the same filter `fetch` uses); `range` and `if-range` are dropped because the player decides ranges; `cookie` and `authorization` are kept |
| `mimeType` | starts with `audio/`, or is `video/webm` or `video/mp4`, or is an HLS playlist type (parameters allowed; compared lower-case, trimmed); anything else is `invalidOutput`. The HLS types are `application/vnd.apple.mpegurl`, `application/x-mpegurl`, `audio/mpegurl` and `audio/x-mpegurl`: `url` is then an HLS playlist (media or master) rather than a file, checked by the same rules as any `url`. Every other accepted type is a progressive file. Nothing is sniffed from the content. `audio/mpegurl` and `audio/x-mpegurl` were accepted before but never played; they now mean HLS |
| `bitrate` | a positive integer, else none |
| `expiresAtMs` | an integer above 0, Unix epoch **milliseconds**; anything else means unknown. A seconds value (`expiresAt`) is not read |

`apiVersion` stays 1: an older build refuses `application/*` types as `invalidOutput` and never played `audio/*mpegurl`, so no plugin that works today changes. The `formats` input lets a plugin tell builds that play HLS from those that do not.

## HLS streams

A `stream.js` that returns an HLS playlist type as `mimeType` (see the table above) hands the app a *media playlist* (segments) or a *master playlist* (variants). Only **VOD** is played: a media playlist must end in `#EXT-X-ENDLIST`. The player never reads the playlist: the app loads and checks it inside the resolve (the same resolve, deadline, expiry, `fresh` and dead mark as a progressive stream, see [Playback](#playback)), then writes its own playlist whose every line points back at the loopback proxy.

- **Variant choice** (a master; one master hop at most, the chosen URI must be a media playlist, else the playlist is refused as invalid). In this order: (1) audio-only variants (`CODECS` present and every codec audio): the highest `BANDWIDTH`; (2) else `EXT-X-MEDIA:TYPE=AUDIO` renditions that have a `URI`: the group named by `AUDIO` of the highest-`BANDWIDTH` variant whose group exists, in it `DEFAULT=YES`, else `AUTOSELECT=YES`, else the first listed; (3) else variants that may carry audio (`CODECS` absent, or at least one audio codec): the lowest `BANDWIDTH`; (4) else refused (nothing to play as audio). Audio codecs are the `CODECS` entries starting with `mp4a`, `ac-3`, `ec-3`, `opus`, `flac` or `alac`. A missing or bad `BANDWIDTH` counts as 0, ties go to the first listed, `EXT-X-I-FRAME-STREAM-INF` is never chosen.
- **Accepted tags**: `#EXTM3U` (first line, after an optional UTF-8 BOM; LF or CRLF), `EXT-X-VERSION`, `EXT-X-TARGETDURATION`, `EXT-X-MEDIA-SEQUENCE`, `EXT-X-DISCONTINUITY-SEQUENCE`, `EXTINF`, `EXT-X-BYTERANGE`, `EXT-X-DISCONTINUITY`, `EXT-X-KEY`, `EXT-X-MAP`, `EXT-X-PLAYLIST-TYPE` (`VOD`, `EVENT`), `EXT-X-ENDLIST`; in a master `EXT-X-STREAM-INF` and `EXT-X-MEDIA`.
- **Ignored tags**: `EXT-X-PROGRAM-DATE-TIME`, `EXT-X-INDEPENDENT-SEGMENTS`, `EXT-X-START`, `EXT-X-ALLOW-CACHE`, `EXT-X-DATERANGE`, `EXT-X-BITRATE`, `EXT-X-GAP`, `EXT-X-SESSION-DATA`, `EXT-X-SESSION-KEY`, `EXT-X-CONTENT-STEERING`, `EXT-X-I-FRAME-STREAM-INF`, the low-latency tags (`EXT-X-PART`, `EXT-X-PART-INF`, `EXT-X-SERVER-CONTROL`, `EXT-X-PRELOAD-HINT`, `EXT-X-RENDITION-REPORT`), any other `#EXT` tag, comments and blank lines.
- **Refused** (the track is skipped; the log line is `hls <kind>`, never a URL): no `#EXTM3U`, `EXT-X-SKIP`, `EXT-X-DEFINE`, both variants and segments in one playlist, a bad attribute list, number, duration or IV, an `EXTINF` without a URI line or a URI line without `EXTINF`, an `AES-128` key without `URI`, a `BYTERANGE` without an offset that does not continue the previous range of the same URI, no segment at all, a master behind a master (`invalid`); no `EXT-X-ENDLIST` (`live`); an `EXT-X-KEY` whose `METHOD` is not `NONE` or `AES-128`, or whose `KEYFORMAT` is not `identity` (`protected`: `SAMPLE-AES`, DRM); `EXT-X-I-FRAMES-ONLY`, or a master with nothing to play as audio (`noAudio`); a URL on a host the plugin did not declare, or a `data:` URI (`blockedHost`); a playlist over a bound below (`tooLarge`).
- **Bounds.** The playlist body is at most 4 MiB and must arrive within 15 seconds of its headers; at most 20,000 segments, 200 variants and 200 renditions; a line at most 16 KiB and a URI at most 8 KiB; each `EXTINF` above 0 and at most 3600 seconds, the total at most 24 hours; a byte range at least 1 byte long ending at or below 2^53. Only one master and one media playlist are fetched per resolve.
- **URL rules.** Every URL the playlist names (variant, segment, init section, key) is resolved against the URL the playlist was finally fetched from (after redirects), and each must pass the same checks as the `url` itself (`https`, no port, no user info, a host the plugin declared). One that fails refuses the whole playlist. Each request the proxy makes for the playlist carries the plugin's `headers` and `accept-encoding: identity`, never a `range` (a `range` is sent only for a byte-range segment or init section), is preceded by the consent check, follows at most 3 checked redirects and connects to public addresses only.
- **`403` on a playlist.** It counts as the `403` of a progressive stream: the same resolve goes on with `fresh: true` (a second `stream.js` run and its playlist fetches, inside the same 20-second deadline) when the playthrough's one `fresh` resolve is left; a second `403`, or a `403` after an earlier request spent it, marks the item dead. Any other status (404, 5xx), a network error or a refusal fails the resolve and marks the item dead.
- **The playlist the player gets** is written by the app, never copied: `EXT-X-VERSION:7`, the `EXT-X-TARGETDURATION` rounded up, `EXT-X-MEDIA-SEQUENCE`, `EXT-X-PLAYLIST-TYPE:VOD`, per segment `EXT-X-DISCONTINUITY`, `EXT-X-KEY`, `EXT-X-MAP` and `EXTINF` with three decimals, then `EXT-X-ENDLIST`. A `KEY` line is written whenever the key state changes (another key file, another IV, or `METHOD=NONE` when a key stops applying); an explicit `IV` is kept as given, and two derived IVs (no `IV` attribute) are one state. An `EXT-X-MAP` is written under the key state it had in the upstream playlist, because the player reads an init section under the key in force at its line: a clear init in front of an encrypted segment is `MAP` then `KEY` (after `METHOD=NONE` when a key was in force), an encrypted one is `KEY` then `MAP`, and a later `MAP` under the same state gets no `KEY` line. A byte-range segment is written as a plain URL (the proxy asks upstream for the range), so no `BYTERANGE` is written. Segments, init sections and keys are named `hls/<rev>/s<i>.<ext>`, `hls/<rev>/i<j>.mp4` and `hls/<rev>/k<j>.key` under the item's proxy URL; `<rev>` numbers the playlist snapshot of the resolve. Key files are numbered by key URI in order of first appearance, so a playlist that repeats one key URI with a new `IV` on each segment has one `k0.key` (fetched once) and one `KEY` line per segment.
- **AES-128 is left to the player.** The proxy serves the key like any resource and keeps `IV` as the playlist gave it; the player's libavformat (`crypto` protocol) decrypts and derives a missing IV from the media sequence. The app has no AES code of its own and adds no dependency for it.

## Errors

A script reports a failure with `Response.error(message, {kind})`. The kinds are `auth`, `rateLimited`, `quota`, `invalidResponse` and `server`; any other text reaches the app as `server`. The app turns every way a call can end into one failure kind (`SourceFailureKind`) and shows text chosen by the app from it:

| What happened | Shown as |
|---|---|
| `Response.error` with `auth` | `auth`: sign-in or credentials problem |
| `Response.error` with `rateLimited` or `quota` | `rateLimited` |
| `Response.error` with `invalidResponse` or `server`, a thrown error, the heap or stack limit | `unavailable`: the service is unavailable. A `server` error or a thrown error after a failed `fetch` takes the kind of that `fetch` instead (`network`, `rateLimited`) |
| a failed `fetch`, a timeout, plugin files that took too long to load | `network` |
| output that breaks the rules above, or over 2 MiB | `invalidOutput` |
| the runtime is full | `busy` |
| a required setting is empty | `needsConfig`; the script does not run |
| the user has not accepted the plugin's notice | `notConsented`; nothing runs or is sent |
| the plugin is missing, removed, being updated, or the app no longer wants the answer | `skipped`; nothing is shown |
| the runtime failed, or the plugin's files or settings cannot be read | `internal` |

A `fetch` failure the script caught does not fail a call that then returns valid output, except a send refused for want of consent. The `Response.error` message is kept with the failure: it goes to the log, and the Online screen shows it under a failed search ("Plugin message: …", at most three lines; the runtime cuts it at 1000 characters). Write it for the user, and keep secrets out of it.

Every failed run, and every run that printed to the console, is written to the plugin's log as for lyrics plugins (the script input is the `query`, so a search text is in it; the file stays on the device). Skipped, busy and not consented calls are not logged. The stream URL and headers a `stream.js` returned are never logged.

## Limits

Unchanged from other plugins: at most 10 HTTP sends and 15 seconds of wall time per call, 2 MiB of output, the same heap and stack caps. See [Limits](./lyrics-plugin-api.md#limits).

`cacheStorage` is **not** provided. A plugin that wants to remember something between calls (a signature function, a visitor id) uses `localStorage` (64 KiB), which the app keeps per plugin.

## Consent

A source plugin may send nothing until the user accepts a notice for **that plugin**. The accepted plugin ids are stored in settings (`onlineSources.noticeAcknowledged`, at most 64). The app checks it before a script starts (without consent `search.js` and `stream.js` do not run), before every `fetch` the script makes, once the script is over (what it returned after a withdrawal is not used), and before each chunk the proxy asks upstream. Withdrawing it stops the next send, and uninstalling the plugin removes its id. The Online screen shows the notice (the plugin's name and its hosts) when a search finds no consent, and runs that search once it is accepted. An update that adds hosts does not ask again, as for translate plugins. An update never changes the kind: an update with another `type` is refused.

## Playback

The app does not hand the stream URL of a plugin to the player. A remote item plays through a small loopback HTTP proxy inside the app (`lib/core/sources/proxy/`): the player is given `http://127.0.0.1:<port>/<token>/source-plugin/<installId>/<item id>` (the item id percent-encoded as one path segment), and the proxy fetches the bytes upstream on its behalf. The port is chosen by the OS when the first item is played and the token is 32 random bytes; both stay the same for the app session, so the URL is useful to no other program or page.

- **Who may ask.** The `Host` header must be exactly `127.0.0.1:<port>` (else `404`), the method `GET` (else `405`), and the path `/<token>/source-plugin/<installId>/<item id>` of an item the player has opened (else `404` with an empty body). Only the last 16 items opened are kept, plus any older one whose answer is still being sent: a request for an item past them is `404` too, without running `stream.js`, until the player opens it again.
- **Lazy resolve.** An item is resolved (`stream.js`, plus its playlists for an HLS item) when the player first requests the proxy URL, or when the app asks the proxy for the item's format (`formatOf`, in "HLS: what the user sees" below), whichever comes first. The app asks for the queued next track as soon as its URL is handed out, and for the track being opened once that open has stayed the newest for 300 ms (`remoteOpenGrace`, `lib/core/player/remote_open_wait.dart`); an open superseded within those 300 ms never resolves. So a queued next remote track is resolved when it is queued, not when it starts, and skipping through tracks runs `stream.js` once for each track the user stays on for at least 300 ms, plus once for each queued next, in order behind earlier runs. A resolve made at queue time may expire before the track plays and is then redone (one plain resolve, as for any expired one); a `403` during that early resolve spends the playthrough's one `fresh`, as any `403` would. A resolve that fails at queue time (a transient plugin error, a rate limit reached by skipping) marks that playthrough dead like any failed resolve, so when the player reaches the track it gets `502` and skips it, with no second try; this holds for progressive and HLS items alike and is a known effect, not changed. Each time the player opens an item (every play, every move to the next track) a new *playthrough* starts; every request of it (the player opens several at once for a WebM file, and one per seek or reconnect) shares one resolve. Opening an item that is already open (repeat all on a one-track queue) starts a playthrough that takes over the resolve already made or still running, so `stream.js` does not run again and a request waiting on it still gets its answer; only the `fresh` budget and the dead mark start anew. A resolve that takes longer than 20 seconds is given up.
- **Checks on the URL.** Before anything is fetched, the URL must be `https`, without a port or user info, on a host the plugin declared; the connection then goes only to public addresses (as for `fetch`).
- **Expiry.** A resolved URL is used until 60 seconds before `expiresAtMs`; after that, one plain resolve (no `fresh`) replaces it. Without `expiresAtMs` it is used until the host refuses it. An `expiresAtMs` already inside those 60 seconds counts as unknown.
- **`fresh` on 403.** The first `403` from the host spends the playthrough's one `fresh: true` resolve and retries the same bytes with the new URL. A second `403` marks the item dead for that playthrough: every further request for it fails at once without running `stream.js`, until the player opens the item again. A failed resolve does the same.
- **Range chunking.** Every upstream request names a closed range of at most 8 MiB (`range: bytes=p-q`; some hosts refuse open ranges), whatever the player asked for. The size of the whole stream comes from the first answer's `Content-Range` (or `Content-Length` when the host ignored the range). Each later chunk must start at the next byte and report the same total size; otherwise (a fresh URL pointing at another file, say) the body ends and the player reconnects, instead of receiving foreign bytes. The proxy answers the player `200` or `206` with `accept-ranges: bytes`, `content-length` and `content-range`; `416` for several ranges or one past the end.
- **Headers.** Every upstream request carries the plugin's `headers`, `accept-encoding: identity` and the proxy's own `range`. The proxy's `content-type` is the plugin's `mimeType` when it has the shape of a media type in printable ASCII, else the host's, else none; neither is copied unchecked.
- **Checked redirects.** A `3xx` from the host is followed at most 3 times, with the same headers and range, and only to a URL that passes the same rules as the `url` (`https`, no port or user info, a host the plugin declared); any other redirect fails the request (`502`). googlevideo redirects to another of its hosts now and then.
- **Consent and uninstall.** Consent is asked before each upstream chunk, so withdrawing it stops the stream at the next chunk. Uninstalling the plugin or withdrawing its consent ends its open streams at once, and its items are refused (`404`) without running `stream.js` until it is installed and accepted again.
- **HLS items.** The path above is the *entry URL* of an HLS item too, but it answers the playlist the app wrote (`200`, `application/vnd.apple.mpegurl`, any `Range` ignored), not bytes. Its segments, init sections and keys are requested at `<entry URL>/hls/<rev>/s<i>.<ext>`, `.../hls/<rev>/i<j>.mp4` and `.../hls/<rev>/k<j>.key`: seven path segments, so a path of five, six or eight segments, a fifth segment other than `hls`, a `rev` or number with a leading zero or too many digits, an index past the playlist, or an ext the kind does not allow is `404` with an empty body. They obey the same `Host`, method, token, item and playthrough checks as the entry URL, and are served only under the item's current playthrough. `<rev>` numbers the playlist snapshot of a resolve: the rev of the current snapshot is always served; the rev of an earlier snapshot of the same item is served from the current snapshot when both have the same layout (media sequence, segment count, and per segment its duration in whole milliseconds, discontinuity, key file and IV (explicit or derived) and init section; per init section the key state in force at its `EXT-X-MAP` line), so a player that holds a playlist from before a re-resolve goes on; an unknown or forgotten rev is `404`, another layout is `502` (not marked dead). Opening the item again (repeat) keeps serving its old sub-resource URLs. The proxy keeps the last 64 snapshots of a session.
- **HLS: expiry, `fresh` and the dead mark for segments.** A resolve (the `stream.js` run and its playlist fetches) is valid until 60 seconds before `expiresAtMs`; a request after that starts one plain resolve and is served through the layout binding above. A `403` on any upstream request of the item (playlist, variant, segment, init section, key) spends the playthrough's one `fresh` resolve, and the request is retried against the snapshot that comes back (if its layout is the same, else `502`); a second `403` marks the item dead. A failed resolve marks it dead too. A segment, init section or key that fails any other way (404, 5xx, network, a bound) fails that request with `502` only: the item stays alive. A key whose body is not exactly 16 bytes is `502` (`hls badKey`). Segments are at most 32 MiB (a longer body is cut there, a response that says it is longer is refused), init sections at most 4 MiB, and the client's `Range` is answered over the resource.
- **HLS: consent and uninstall.** Sub-resource bodies end at once on uninstall or consent withdrawal, like any other body; the next request for the item is `404` without running `stream.js`. After a restore the item is served again from the next time the player opens it.
- **HLS: what the user sees.** A playable HLS track behaves like a file: its duration is the sum of the `EXTINF` values, it has a seek bar and plays on to the next track. A track whose resolve is refused or fails is skipped with a message: for a live stream ("live streams aren't supported") and a protected one ("protected streams aren't supported") the app picks the text from the refusal the proxy remembers (`remoteStreamRefusalProvider`), for anything else it is the general "couldn't play". The entry URL of such an item answers `502`. The proxy tells which format an entry URL has (`formatOf`, which waits for the shared resolve), so the player can allow the network protocols only for HLS items.
- **HLS: a segment that fails while playing.** Measured with mpv 0.41 (libavformat 63): a segment that answers an error is retried three times (six HTTP requests in a few milliseconds), then skipped, and playback goes on with the next one: the track has a gap of that segment's length and no message. A segment that never answers costs about 180 seconds (six tries of the 30-second network timeout) before it is skipped. Only a failure while opening the file (the entry `502`, or the first segments failing during the probe) ends the track with an error. This is how it is; the proxy does not change it.
- **Failures.** Anything that fails before the proxy answered (the resolve, the URL checks, the host) is `502` and the player skips the track; a failure while bytes are flowing ends the body. The proxy logs the plugin id, the status, `resolve failed: hls <kind>` (one line) for a refused or failed resolve, `hls playlist 502: <reason>` when it cannot write the playlist (consent withdrawn), `hls segment|init|key failed: <reason>` for a failed sub-resource, and byte counts only, never the URL, its query or the proxy token.
