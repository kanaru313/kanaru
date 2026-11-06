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
| `next` | a string of at most 8 KiB; dropped when equal to the `next` that was sent |

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
| `url` | absolute `https`, at most 8 KiB, no explicit port, no user info. Its host must be one the plugin declared |
| `headers` | at most 20 string entries, filtered like any plugin request header (the same filter `fetch` uses); `range` and `if-range` are dropped because the player decides ranges; `cookie` and `authorization` are kept |
| `mimeType` | starts with `audio/`, or is `video/webm` or `video/mp4` (parameters allowed); anything else is `invalidOutput` |
| `bitrate` | a positive integer, else none |
| `expiresAtMs` | an integer above 0, Unix epoch **milliseconds**; anything else means unknown. A seconds value (`expiresAt`) is not read |

## Errors

A script reports a failure with `Response.error(message, {kind})`. The kinds are `auth`, `rateLimited`, `quota`, `invalidResponse` and `server`; any other text reaches the app as `server`. The app shows these to the user as:

| Plugin kind | Shown as |
|---|---|
| `auth` | sign-in or credentials problem |
| `rateLimited`, `quota` | rate limited |
| `invalidResponse`, `server` | the service is unavailable |
| fetch error, timeout | network problem |
| output that breaks the rules above | invalid output |
| the runtime is full (`busy`) | busy |

The message the script passed is kept for the log; the screen shows text chosen by the app from the kind.

## Limits

Unchanged from other plugins: at most 10 HTTP sends and 15 seconds of wall time per call, 2 MiB of output, the same heap and stack caps. See [Limits](./lyrics-plugin-api.md#limits).

`cacheStorage` is **not** provided. A plugin that wants to remember something between calls (a signature function, a visitor id) uses `localStorage` (64 KiB), which the app keeps per plugin.

## Consent

A source plugin may send nothing until the user accepts a notice for **that plugin**. The accepted plugin ids are stored in settings (`onlineSources.noticeAcknowledged`). The app checks it before every send: each search, each stream resolve and each chunk the proxy asks upstream. Withdrawing it stops the next send, and uninstalling the plugin removes its id. An update that adds hosts does not ask again, as for translate plugins. An update never changes the kind: an update with another `type` is refused.

## Playback

The app does not hand the stream URL of a plugin to the player. A remote item plays through a small loopback HTTP proxy inside the app: the player is given `http://127.0.0.1:<port>/…`, and the proxy calls `stream.js` lazily when the player asks for the bytes, adds the plugin's `headers`, and fetches them from the `url` over https from the hosts the plugin declared. When the stream expires (`expiresAtMs`) or the host refuses it, the proxy asks `stream.js` once more with `fresh: true`. The details of the proxy are documented with the proxy itself.
