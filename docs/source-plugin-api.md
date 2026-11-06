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
| `id` | 1 to 200 characters, no control characters |
| `title` | 1 to 300 characters after the usual name cleaning |
| `artist` | at most 200 characters, else none |
| `durationMs` | an integer from 1 to 86 400 000; anything else (a plugin's `0` included) means unknown |
| `artworkUrl`, `webUrl` | kept only as an absolute `https` URL of at most 2000 characters without user info, else none |
| `next` | a string of at most 8 KiB; a longer or empty one, or one equal to the `next` that was sent, means no next page. A page with no items and a `next` is allowed |

An output that is not an object with an `items` array, or whose `next` is neither a string nor null, is `invalidOutput`.

## `stream.js`

Input: `{ "id": "<item id>" }`, or `{ "id": "<item id>", "fresh": true }`. `fresh` is left out when false; `true` asks the plugin to skip its own cache and resolve the stream again (the previous URL was refused).

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
| `mimeType` | starts with `audio/`, or is `video/webm` or `video/mp4` (parameters allowed); anything else is `invalidOutput` |
| `bitrate` | a positive integer, else none |
| `expiresAtMs` | an integer above 0, Unix epoch **milliseconds**; anything else means unknown. A seconds value (`expiresAt`) is not read |

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

A `fetch` failure the script caught does not fail a call that then returns valid output, except a send refused for want of consent. The `Response.error` message is kept with the failure for the log; the screen never shows it.

Every failed run, and every run that printed to the console, is written to the plugin's log as for lyrics plugins (the script input is the `query`, so a search text is in it; the file stays on the device). Skipped, busy and not consented calls are not logged. The stream URL and headers a `stream.js` returned are never logged.

## Limits

Unchanged from other plugins: at most 10 HTTP sends and 15 seconds of wall time per call, 2 MiB of output, the same heap and stack caps. See [Limits](./lyrics-plugin-api.md#limits).

`cacheStorage` is **not** provided. A plugin that wants to remember something between calls (a signature function, a visitor id) uses `localStorage` (64 KiB), which the app keeps per plugin.

## Consent

A source plugin may send nothing until the user accepts a notice for **that plugin**. The accepted plugin ids are stored in settings (`onlineSources.noticeAcknowledged`, at most 64). The app checks it before a script starts (without consent `search.js` and `stream.js` do not run), before every `fetch` the script makes, once the script is over (what it returned after a withdrawal is not used), and before each chunk the proxy asks upstream. Withdrawing it stops the next send, and uninstalling the plugin removes its id. The Online screen shows the notice (the plugin's name and its hosts) when a search finds no consent, and runs that search once it is accepted. An update that adds hosts does not ask again, as for translate plugins. An update never changes the kind: an update with another `type` is refused.

## Playback

The app does not hand the stream URL of a plugin to the player. A remote item plays through a small loopback HTTP proxy inside the app (`lib/core/sources/proxy/`): the player is given `http://127.0.0.1:<port>/<token>/source-plugin/<installId>/<item id>` (the item id percent-encoded as one path segment), and the proxy fetches the bytes upstream on its behalf. The port is chosen by the OS when the first item is played and the token is 32 random bytes; both stay the same for the app session, so the URL is useful to no other program or page.

- **Who may ask.** The `Host` header must be exactly `127.0.0.1:<port>`, the method `GET` (else `405`), and the path `/<token>/source-plugin/<installId>/<item id>` of an item the player has opened (else `404` with an empty body).
- **Lazy resolve.** `stream.js` runs when the player first requests the proxy URL, not when the item is queued. Each time the player opens an item (every play, every move to the next track) a new *playthrough* starts; every request of it (the player opens several at once for a WebM file, and one per seek or reconnect) shares one resolve. A resolve that takes longer than 20 seconds is given up.
- **Checks on the URL.** Before anything is fetched, the URL must be `https`, without a port or user info, on a host the plugin declared; the connection then goes only to public addresses (as for `fetch`).
- **Expiry.** A resolved URL is used until 60 seconds before `expiresAtMs`; after that, one plain resolve (no `fresh`) replaces it. Without `expiresAtMs` it is used until the host refuses it. An `expiresAtMs` already inside those 60 seconds counts as unknown.
- **`fresh` on 403.** The first `403` from the host spends the playthrough's one `fresh: true` resolve and retries the same bytes with the new URL. A second `403` marks the item dead for that playthrough: every further request for it fails at once without running `stream.js`, until the player opens the item again. A failed resolve does the same.
- **Range chunking.** Every upstream request names a closed range of at most 8 MiB (`range: bytes=p-q`; some hosts refuse open ranges), whatever the player asked for. The size of the whole stream comes from the first answer's `Content-Range` (or `Content-Length` when the host ignored the range). Each later chunk must start at the next byte and report the same total size; otherwise (a fresh URL pointing at another file, say) the body ends and the player reconnects, instead of receiving foreign bytes. The proxy answers the player `200` or `206` with `accept-ranges: bytes`, `content-length` and `content-range`; `416` for several ranges or one past the end.
- **Headers.** Every upstream request carries the plugin's `headers`, `accept-encoding: identity` and the proxy's own `range`. The proxy's `content-type` is the plugin's `mimeType` when it has the shape of a media type in printable ASCII, else the host's, else none; neither is copied unchecked.
- **No redirects.** A `3xx` from the host is not followed: the request fails (`502`). Return the final URL from `stream.js`.
- **Consent and uninstall.** Consent is asked before each upstream chunk, so withdrawing it stops the stream at the next chunk. Uninstalling the plugin or withdrawing its consent ends its open streams at once, and its items are refused (`404`) without running `stream.js` until it is installed and accepted again.
- **Failures.** Anything that fails before the proxy answered (the resolve, the URL checks, the host) is `502` and the player skips the track; a failure while bytes are flowing ends the body. The proxy logs the plugin id, the status and byte counts only, never the URL, its query or the proxy token.
