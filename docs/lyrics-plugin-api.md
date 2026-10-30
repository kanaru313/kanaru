# Lyrics plugin API

What a lyrics plugin script can rely on. Plugins are JavaScript files in the package's `src/` folder; the app runs them in the Rust plugin runtime (`rust/src/plugin_runtime/`). Architecture: [system-architecture.md](./system-architecture.md#plugin-runtime).

## Runtime and limits

### Limits

The values live in `rust/src/plugin_runtime/limits.rs`; a test pins them.

| Limit | Value | When hit |
|---|---|---|
| Heap | 32 MiB, counted by a Rust allocator (`memory.rs`) that sets a flag when it refuses an allocation, so `memory` is reported even when the engine could not build the error object | status `memory` |
| JS stack | 1 MiB (the thread has 8 MiB, so the engine fails first, also inside `JSON.parse` and `String(nested array)`) | status `stack` |
| Wall time per call | 15 s, counted from the moment a worker starts the job (includes `load()`); time waiting in the queue is not counted, so the host keeps its own outer deadline | status `timeout` |
| Output | 2 MiB of JSON text (UTF-8 bytes) | status `outputTooLarge` |
| Thrown-error text in `js_error` | message 1000 characters, stack 16 KiB (cut, not rejected) | cut |
| `fetch` request body | 256 KiB | `InvalidRequestError` |
| HTTP sends per call (retries included) | 10 | `TooManyRequestsError` |
| Unread `fetch` bodies and parsed `Html` documents in Rust memory | 16 MiB per call, shared | status `memory` |
| `Html.parse` text | 4 MiB (UTF-8 bytes) | `RangeError` |
| Parsed documents per call | 8 | `RangeError` |
| Nodes per parsed document | 200 000 | `RangeError`, and the call ends `memory` |
| Element nesting depth of a parsed document | 512 (`<html>` is level 1, `<body>` level 2) | `RangeError` |
| `localStorage` | 64 KiB of keys plus values | `QuotaExceededError` |
| Console | 500 characters per line, 50 lines per call | cut / `… N lines dropped` |
| Worker threads | 4 | extra jobs wait |
| Queued jobs | 16 | the 17th waiting job is `busy` |

A timeout and a cancel use an interrupt the script cannot catch, so `try { while (true) {} } catch (e) {}` still stops. Every call gets a fresh engine; globals do not survive between calls.

### Script contract

The entry file (`search.js` or `lyrics.js`) and every file it `load()`s run as **classic global scripts** in one scope, in sloppy mode. There is no module system: `import`, `export` and dynamic `import()` are syntax or runtime errors, and `std`, `os`, `require`, `setTimeout`, `setInterval`, `XMLHttpRequest` and `WebSocket` do not exist (`sleep` is the only wait). `eval` and `Function` exist (they add no capability). Promises can be created but are never resolved: the host does not run the job queue.

After the entry file ran, the host calls the global `execute(input)` once. `input` is the request's JSON, parsed. It must return a value made by `Response`:

| Call | Result |
|---|---|
| `Response.success(data)` | status `ok`, `output_json` = `JSON.stringify(data)` (`null` for `undefined`) |
| `Response.error(message, {kind, retryAfterSec})` | status `scriptError`, `error_message` = `message` (cut at 1000 characters), `error_kind` = `kind`, `retry_after_sec` = `retryAfterSec` |

`kind` is `rateLimited`, `invalidResponse` or `server`; anything else, or no `kind`, is `server`. `retryAfterSec` counts only as a finite number of 0 or more (rounded down).

Returning anything else (a Promise, `undefined`, a plain object that merely looks like a response) is status `scriptError` with `error_kind` `invalidResponse` and the message `execute must return Response.success or Response.error`. A missing `execute` is `scriptError` too. `Response` is read-only and a response cannot be forged: the helpers keep their own copies of the built-ins they use.

### `load(name)`

`load('util.js')` runs another file of the package's `src/` in the same global scope.

- `name` must match `^[A-Za-z0-9_.-]+\.js$` (no `/`, no `..\`), and the file must be one the caller sent with the request. Otherwise `load` throws an `Error` the script may catch.
- A file runs at most once per call; the entry file counts as loaded. A second `load` of the same name does nothing.
- `crypto.js` is the bundled CryptoJS ([below](#loadcryptojs)); a package file of that name is never used.

### Result

`run_plugin_script` always returns a `PluginScriptResult`. These fields are filled **on every status**, including failures:

| Field | Meaning |
|---|---|
| `status` | `ok`, `scriptError`, `timeout`, `memory`, `stack`, `cancelled`, `outputTooLarge`, `internal`, `busy` |
| `output_json` | the data of `Response.success`; empty unless `ok` |
| `error_message`, `error_kind`, `retry_after_sec` | explanation of any non-`ok` status; kind and retry hint for script-reported failures |
| `js_error` | the JavaScript exception that ended the run: `message` and `stack` (file names and line numbers kept, e.g. `search.js:12:5`). Set for thrown errors, syntax errors in the entry or a loaded file, and for `timeout`, `memory`, `stack` and a cancel of a running job (the engine's interrupt or limit exception). Not set when no script code was running or the host found the problem after `execute` returned: `cancelled` before start, `busy`, `internal`, `outputTooLarge`, `Response.error`, a non-`Response` return, a missing `execute` |
| `logs` | console lines captured before the run ended, whatever the status |
| `fetch_failure` | the first failing `fetch` of the call, even if the script caught the error |
| `storage_json` | the plugin's whole new storage map, only when the script changed it **and** finished on its own (status `ok` or `scriptError`); `None` for every other status |

`logs`, `fetch_failure` (and `js_error`) are plumbed through every failure path (a per-job collector outlives the script, even a panic): a `timeout`, `memory` (heap or the Rust byte budget), `stack`, `cancelled`, `outputTooLarge`, `scriptError` or a panicking host callback still returns the console lines written so far, the `js_error` when the engine had one, and the first `fetch` failure. Tests cover each of these.

Other statuses:

- `cancelled`: `cancel_plugin_job` was called; also returned at once for an unknown, already used or cancelled-before-start job id. A cancel of a running job is seen within about 100 ms; a job still waiting in the queue ends `cancelled` at once and gives its queue slot back.
- `internal`: the runtime failed, not the script: a worker panicked, `input_json` is not valid JSON, the entry file is not in the request, or two files share a name. The next job still runs.
- `busy`: all 4 workers are busy and 16 jobs are waiting. Nothing ran. The host skips this source for the lookup, records no failure and starts no pause.

### Syntax check

`check_plugin_script(name, code)` compiles a file without running it: a top-level `throw` or an endless loop is not executed. It returns `None` when the file parses, else the message and the 1-based line.

### Job ids

`begin_plugin_job()` returns an id, `run_plugin_script` runs under it, `cancel_plugin_job(id)` stops it. An id runs once. Cancelling an id that has not started removes it, so nothing leaks if the run call never comes; cancelling an unknown or finished id does nothing.

### Dart API

`lib/core/plugin_runtime/` wraps the bindings; only `rust_plugin_runtime.dart` imports the generated code. It is generic and imports nothing from `core/lyrics`; the lyrics host maps its results to `LyricsFetchKind`. `pluginRuntimeProvider` (`Provider<PluginRuntime>`, no dependencies) gives the runtime; tests substitute their own `PluginRuntime`.

- `PluginRuntime.run(PluginRunRequest, {required PluginFetcher fetch, PluginCancel? cancel})` returns a `PluginRunResult` and does not throw for a failed run. `PluginRunRequest`: `files` (`PluginSourceFile` name and code), `entry`, `inputJson`, `timeout` (null = runtime maximum), `config` (map), `storageJson` (empty = none). A bridge failure or a library that cannot load is returned as status `internal`, never thrown (a begun job id is cancelled to free it; a failing cancel listener is ignored).
- `PluginRunResult` has the same fields as `PluginScriptResult` on every status: `status` (`PluginRunStatus`: `ok`, `scriptError`, `timeout`, `memory`, `stack`, `cancelled`, `outputTooLarge`, `internal`, `busy`), `outputJson`, `errorMessage`, `errorKind`, `retryAfterSec`, `jsError` (`message`, `stack`; null when there is no exception, `stack` null when the engine gave none), `logs` (unmodifiable), `fetchFailure` (`kind`, `retryAfterSec`, `message`; null when no fetch failed) and `storage` (the new storage JSON; null unless the status is `ok` or `scriptError` and the script changed it).
- `PluginFetcher` answers a `PluginFetchCall` (`method`, `Uri url`, `headers`, `Uint8List body`, `deadline` as a `Duration`, `maxSends`) with a `PluginFetchAnswer` (`outcome`, `status`, final `url`, `headers`, `bytes`, `retryAfterSec`, `sends`). A fetcher that throws is answered as `network` (sends 0; Rust counts at least 1 for a network failure), and an `ok` answer without a final URL gets the call's URL, and a URL that is not a valid `Uri` is answered `invalidRequest` without calling the fetcher, so a bug in the app never crashes a job. A fetcher that is slower than the deadline is cut by the runtime (`timeout`). Numbers in an answer are clamped to the ranges the bridge encodes.
- `PluginCancel.cancel()` calls `cancel_plugin_job` for a running job. A token cancelled before the run still goes through Rust: the job is begun, cancelled (which frees its id) and run, so the result is `cancelled` and no script code runs. A token stays cancelled and can serve several runs.
- `check(fileName, code)` returns `PluginScriptProblem?` (`message`, `line` or null when unknown). Unlike `run` it throws when the library cannot load or the bridge fails: null would claim an unchecked script is valid.
- A `timeout` of zero or under 1 ms is sent as 1 ms (Rust reads 0 as the 15 s maximum). `PluginFetchAnswer.sends` defaults to 0; `blockedHost` and `notConsented` answers use up no sends (the first failure is still kept as `fetch_failure`).
- The `native`-tagged test (`test/core/plugin_runtime/rust_plugin_runtime_native_test.dart`) runs only after `cargo build --manifest-path rust/Cargo.toml`; it skips with a message when the debug library is missing or cannot be loaded (for example a stale build).
- The runtime logs only the type of an error, never a URL, header or configuration value.

### Binary size

Cumulative release `librust_lib_kanaru.so` growth of the runtime work is 3,452,392 B (3.29 MiB) over the baseline of 10,678,816 B, inside the 4 MiB budget (14,131,208 B measured with `cargo build --release`). The Dart wrapper adds no native code.

## Host API

Besides `Response` and `load`, a script has these globals. They are ordinary global properties (a package may declare its own `sleep` or `console`). Everything is synchronous; there are no Promises. The runtime knows nothing about hosts or consent: the app answers `fetch` through a callback (see [system-architecture.md](./system-architecture.md#plugin-runtime)).

### `fetch(url, options?)`

`options`: `method` (`GET` default, or `POST`, any case; anything else throws `TypeError`), `headers` (object), `body` (string, sent as UTF-8; or an object, sent as JSON with `content-type: application/json` unless a content-type header is given), `queries` (object, appended to the URL percent-encoded; `undefined` and `null` values are skipped), `timeout` (ms, cut to what is left of the call's 15 s; a bad value is ignored). The request body is at most 256 KiB; a larger one throws `InvalidRequestError` without crossing to the app. The app does the authoritative checks (host allowlist, consent, header and body rules) and returns an outcome.

On success `fetch` returns a frozen object `{status, ok (200-299), url (after redirects), headers (lower-case names; repeated names joined with ", "), header(name) (case-insensitive, null when absent), text(charset?), json(), base64()}`. An HTTP error status such as 404 is still a successful `fetch`.

- `text(charset?)` decodes by the `charset` argument (any label `encoding_rs` knows: `utf-8`, `gbk`, `gb18030`, `big5`, `shift_jis`, `euc-kr`, ...; an unknown one throws `RangeError`), else by the `charset` of the `content-type` header, else UTF-8. Invalid bytes become U+FFFD. `json()` is `JSON.parse(text())` and throws `SyntaxError` on bad JSON.
- A body is read **once**: it stays in Rust memory until the first `text()`, `json()` or `base64()`, then it is released and the result is cached. Calling `text()` or `json()` again returns the cached text (the charset of the first call), but `base64()` after `text()` (or the other way round) throws an `Error`.

Any other outcome throws an `Error` with a `name`:

| Name | Meaning |
|---|---|
| `NetworkError` | connection, TLS or timeout failure |
| `BlockedHostError` | the host is not on the plugin's allowlist, or the URL is not `https` (plain `http`, an explicit port or user info are refused) |
| `NotConsentedError` | the user has not allowed the plugin to use the network |
| `AbortError` | the user stopped the lookup; the call ends `cancelled` even if the script catches this |
| `InvalidRequestError` | the app refused the request (method, headers, body) or the body is over 256 KiB |
| `InvalidResponseError` | the app refused the answer (a body over 4 MiB) |
| `RateLimitedError` | the server asked to slow down; the error has `retryAfterSec` when known |
| `TooManyRequestsError` | the call already used 10 HTTP sends (retries the app made count); nothing is sent |

Each request carries `max_sends`: 10 minus the sends used so far (at least 1 whenever a request is sent). The app must not make more sends than that, retries included. A reply that reports more sends than `max_sends` is counted as `max_sends`, so the total never passes 10.

Error messages made by the runtime are fixed texts: they never contain the URL, headers, body or any `localConfig` value.

**Sticky failure.** The first failing outcome of a call is stored in the result as `fetch_failure` (kind, `retry_after_sec`, text), even when the script catches the error and returns `Response.success([])`, so the app does not cache that as "no lyrics". `TooManyRequestsError` is reported as kind `invalidRequest`.

**Waiting.** The script thread waits for the app until the call's deadline, looking at the cancel flag every 50 ms. An app that never answers ends the call as `timeout`; a callback that throws is answered as `network`; a cancel ends it as `cancelled` within about 100 ms. The request also carries `deadline_ms` (what is left of the call); the app uses the smaller of that and 30 s as the overall timeout.

**Memory.** Response bodies not read yet and parsed `Html` documents are charged to one 16 MiB Rust-side budget per call (the heap cap does not see Rust memory). Responses the script never reads and documents stay charged until the call ends. Going over throws `RangeError` and the call ends with status `memory`, even if the script catches the error and returns normally.

### `sleep(ms)`

Blocks the script thread for `ms` (negative or not a number counts as 0). The time counts toward the call's 15 s: a sleep longer than what is left runs until the deadline and the call ends `timeout`. A cancel interrupts it.

### `localConfig.getItem(key)`

The plugin's configuration as the app set it (secrets included): a string, or `null` when the key is not set. Read-only. The runtime never writes these values to the log or to any message it makes; what a script does with them (for example in `console.log`) is the plugin author's duty.

### `localStorage`

`getItem(key)` (string or `null`), `setItem(key, value)` (both coerced to strings), `removeItem(key)`, `clear()`. The script works on a copy of the plugin's stored map. The quota is 64 KiB of keys plus values (UTF-8 bytes); a `setItem` over it throws `QuotaExceededError` and changes nothing. When the script changed the map and the run finished on its own (`ok`, or `scriptError`: a thrown error, `Response.error`, a non-`Response` return), the result's `storage_json` is the whole new map as a JSON object and the app writes it back. After `cancelled`, `timeout`, `memory`, `stack`, `outputTooLarge`, `internal` or `busy` nothing is returned or saved, even if the script changed the map first. If two calls of one plugin run at once, the last writer wins. Nothing is returned when the map ended as it started.

### `console` and `Log`

`console.log`, `.info`, `.warn`, `.error`, `.debug` and `Log.log` all write one line: the arguments joined by a space (objects through `JSON.stringify`, falling back to `String()`; an `Error` as `String(error)`). A line is cut at 500 characters. A call keeps at most 50 lines; past that the first 49 are kept and the last entry reads `… N lines dropped`. The lines are returned in `logs`; the app adds them to the plugin's own log file (see [Logs](#logs)). Do not log secrets or query strings.

### `Html.parse(text)`

Parses `text` as an HTML document (the browser parsing rules, via the `scraper` crate; a fragment gets `<html><head></head><body>` around it) and returns its `<html>` `Element`. The parse and every query run in Rust on the script thread. The objects hold a private handle into a per-call arena that is dropped with the call; a script cannot read or make up a handle, and `new` on the classes throws.

`Element`:

| Method | Returns |
|---|---|
| `select(css)` | `Elements`: the descendants (not the element itself) that match, in document order |
| `selectFirst(css)` | the first match or `null` |
| `text()` | text content, see below |
| `html()` / `outerHtml()` | inner / outer HTML; at most 4 MiB, more throws `RangeError` and the call ends `memory` (html5ever's repair of misnested markup can clone one big attribute value thousands of times, and the output repeats each clone) |
| `attr(name)` | the attribute value, `""` when absent; the exact name is tried first (SVG keeps `viewBox`), then the lower-case name (HTML names are stored lower case). Names are local names without a namespace prefix: for `xlink:href` ask for `href` |
| `tagName()` | the tag name as the parser gives it: lower case for HTML elements, camel case for SVG ones (`foreignObject`) |

`Elements`: `size()`, `get(i)` (`null` when out of range), `first()` and `last()` (`null` when empty), `text()` (the `text()` of each element joined with `\n`), `attr(name)` (of the first element, `""` when empty), `map(fn)` (an array of `fn(element, index)`), `forEach(fn)`, `toArray()` (an array of `Element`). `get`, `first`, `last` and `toArray` make new `Element` objects on each call (compare by content, not identity).

`text()` collapses HTML whitespace runs to one space, turns `<br>` into a line break, starts and ends a line at `<p>`, `<div>`, `<pre>`, `<li>`, `<h1>` to `<h6>`, `<tr>`, `<table>`, `<section>`, `<article>`, `<blockquote>`, `<header>` and `<footer>`, separates table cells (`<td>`, `<th>`) with one space, keeps the text of `<pre>` as written (spaces and every line break), keeps at most one blank line in a row outside `<pre>`, and trims line breaks at both ends. Non-breaking spaces are kept; comments, `<script>`, `<style>`, `<template>` and `<noscript>` add nothing (the content of a `<template>` is not part of the text).

Selectors use the CSS selector syntax of the `selectors` crate (type, class, id, attribute, combinators, `:not`, `:nth-child`, ...). A selector the parser rejects (including a nested `:has`), or longer than 1024 bytes, throws `SyntaxError` with the selector text (cut to 80 bytes) and a short reason. Strings passed in must be well-formed Unicode: a lone surrogate throws `TypeError`.

Limits: text over 4 MiB, a 9th document in one call, a document with more than 200 000 nodes, or elements nested more than 512 levels deep throw `RangeError` (a refused parse keeps nothing and uses no slot). A document over the node cap also marks the shared byte budget as overrun, so the call ends `memory` even if the script catches the error; a document that is too deep does not (page depth is a property of the page, not memory). The depth limit keeps `:has` far from the thread stack limit and bounds the cost of one match; real pages are well under 100 levels. Each document is charged to the shared 16 MiB Rust byte budget at 160 bytes per node plus the input size, so a document of about 100 000 nodes or more may hit the budget first: that throws `RangeError` and the call ends `memory`. The parser gets the text 1 KiB at a time and looks at the cancel flag and the deadline after each piece, so a cancel or timeout ends a long parse; its tree sink stops creating nodes at the node cap, so elements html5ever clones while repairing nesting cannot pass it, and the parse stops early once the nesting passes the limit by more than 64 levels (misnested markup can make the running estimate a little too high); the exact depth of the finished tree is what enforces the limit. `select` runs the selector matching itself and counts its work in steps: one per node looked at (siblings and children are walked node by node, so a run of comments counts), one per candidate element, and one per KiB of attribute or class text scanned (a case-insensitive substring search such as `[x*=y i]` counts its needle length on top). The cancel flag and the deadline are looked at every 65 536 steps, so a cancel or timeout ends even a selector that needs minutes (many alternatives, `:has(x span)`, long class lists on a large page) after a bounded amount of further work; a single comparison of one long attribute value is not split, so one check can be about a third of a second late in the worst case. A cancel or timeout during `select` ends the call `cancelled` / `timeout`. The attribute text of every element the parser creates is charged to the same byte budget, clones that the parser makes while repairing misnested markup included (they share memory, but a selector or `html()` reads each copy in full), so the attribute text a selector can ever scan is at most 16 MiB per call; a page that would pass it is refused at `Html.parse` with `RangeError` and the call ends `memory`. A page whose attribute text is small (every realistic page) is not affected.

### `load('crypto.js')`

Evaluates the bundled CryptoJS 4.2.0 (MIT) and defines the global `CryptoJS` (AES with ECB/CBC and PKCS7, MD5, SHA1/SHA256/SHA512, HMAC, `enc.Base64`, `enc.Hex`, `enc.Utf8`, ...). Pure JavaScript inside the sandbox, no extra capability. There is no secure random source: calls that need a random salt or IV (for example `AES.encrypt` with a passphrase string) throw; pass an explicit key and IV.

### What is absent

`XMLHttpRequest`, `WebSocket`, `require`, `import`, `setTimeout`/`setInterval`, and file and process APIs.

## Lyrics scripts in a lookup

How the app uses a plugin (`lib/core/lyrics/plugins/plugin_lyrics_provider.dart`, `plugin_script_runner.dart`, `plugin_output_reader.dart`; data flow in [system-architecture.md](./system-architecture.md#plugin-lyrics-provider-and-source-list)). A plugin has no exact-match call: the app runs `search.js`, matches the results against the song (title, artist, duration) and then runs `lyrics.js` for the best matches.

### `search.js`

`execute(input)` gets one of:

- an automatic lookup or a search by tags: `{title, artist, artists, album, durationMs}`; a missing tag is `null`. `artist` is the primary artist (the first name of the tag) and `artists` the list of all the song's artist names, split like the library splits a tag (`;`, `/`, `feat.`, `ft.`, `featuring`, `with`, with the keep-whole list such as `AC/DC`); `artists` is `null` when there is no artist tag;
- the manual search of the Choose lyrics dialog: `{text}` with the text the user typed.

It returns `Response.success(items)`, an array of at most 20 useful items (more are cut):

| Field | Rule |
|---|---|
| `id` | string, 1 to 256 characters |
| `title`, `artist` | non-empty strings |
| `album` | optional string |
| `durationMs` | optional integer above 0 (a whole number written as `200000.0` is accepted); 24 hours or more is ignored |
| `lyrics` | optional string: lyrics that came with the search result (saves the second call). Read like the `data` of `lyrics.js`; over 1 MiB, the item is dropped |

An item that breaks a rule is dropped, with a note in the plugin's log (`result #4: "artist" must be a non-empty string`); the others are kept. An output that is not an array is an invalid response. Results are checked again by the app (lengths, control characters, duration range) and matched against the song, and an empty array is "no result", not an error. Returning `[]` after a `fetch` that failed is still a failure (see Errors).

### `lyrics.js`

`execute(input)` gets the `id` of a result as a string. It returns `Response.success(value)` with:

- `null`: this record has no lyrics;
- `{instrumental: true}`: the song has no words (wins over `data`);
- `{data, type?}`: `data` is the text (at most 1 MiB, blank means no lyrics); `type` `lrc` is synced text, `txt` is plain text; missing or any other value is synced when the text has a `[mm:ss.xx]` stamp and plain otherwise.

Anything else is an invalid response.

### Errors

The app maps the result of a run to a failure in this order:

1. `cancelled`: nothing is recorded. If the plugin was uninstalled or updated during the run, the source is only skipped for this lookup (like `busy`) and the other sources go on; if the lookup was abandoned, the whole lookup ends;
2. a failed `fetch` of the run, even if the script caught it and returned data: `NetworkError` is `network`, `BlockedHostError` `blockedHost`, `NotConsentedError` `notConsented`, `RateLimitedError` `rateLimited` (with `retryAfterSec` read like a `Retry-After` header, 1 s to 15 min), `InvalidRequestError`, `InvalidResponseError` and `TooManyRequestsError` `invalidResponse`;
3. `Response.error(message, {kind, retryAfterSec})`: kind `rateLimited` (with `retryAfterSec`), `invalidResponse`, or `server` (the default);
4. `busy` (every worker busy and the queue full): the source is skipped for this lookup, with no failure and no pause; the app asks again for the next song or after about 30 s. `timeout` is `network`. `memory`, `stack`, `outputTooLarge`, a thrown error, a bad output shape and an `internal` failure of the runtime are `invalidResponse`.

A failure is never stored as "no lyrics": only a successful empty answer is. A failure pauses that source (and only that source) for at least 60 seconds. Besides the 15 s of script time, a run has an outer deadline of 60 s from the call (queue wait included); when it passes the run is cancelled and counts as `network`.

### Logs

A run that failed, or that printed to `console`, adds one line to `<data>/plugin-logs/<installId>.jsonl` (JSON Lines): `{ts, installId, pluginName, version, script, query, kind, message, stack, console, requests}`. `kind` is `ok` (a run that only printed), `network`, `server`, `rateLimited`, `invalidResponse`, `blockedHost` or `notConsented`. `query` is the input of the run, so the file holds song titles and artists: it stays on this device, is never attached to a bug report automatically and is deleted when the plugin is uninstalled. `requests` has `{method, host, path, status, ms}` for each `fetch` (no query string, header or body; `status` is null when no answer came). Every config value of four characters or more is replaced by `***` in `message`, `stack`, `console` and the request paths. A file over 512 KiB moves to `<installId>.jsonl.1` (the older one is replaced), so a plugin keeps at most about 1 MiB. The app log gets one INFO line per failed run with the plugin's name, id, script and kind (and the host of a blocked address), and nothing else.

### Cookies and private addresses (version 1)

There is no cookie jar. A script that needs a session reads the `set-cookie` header of a response with `res.header('set-cookie')`, keeps what it needs in `localStorage`, and sends a `Cookie` header itself, only to the hosts it declared (a request to any other host is `blockedHost`). The app does not yet block names that resolve to private addresses (see `metadata.hosts`): only the name is checked.

## Plugin package

`lib/core/lyrics/plugins/package/` reads a plugin `.zip` entirely in memory: nothing is written to disk and no script runs. `PluginPackageReader(PluginRuntime).read(bytes)` returns `PluginPackageAccepted(PluginPackage)` or `PluginPackageRejected(PluginPackageProblem)`; a package is accepted whole or not at all. Core holds no UI text: a problem is a `kind` plus `detail` (control characters replaced, cut to 200 code points) (and `line`, `message` for script errors) and the app maps it to a message.

### Layout

```
plugin.json        required
icon.png           optional
src/<name>.js      flat; <name> matches ^[A-Za-z0-9_.-]+$; scripts load each other with load('<name>.js')
```

Other entries are ignored and never unpacked, but their names, count and declared sizes still count toward every limit. If `plugin.json` is not at the root but is at `<dir>/plugin.json` and every entry is under `<dir>/`, that one folder is stripped (zipping a folder is the common mistake). A deeper or partial folder is not stripped.

### Zip rules

Any failure refuses the whole package.

- File over 5 MiB: `tooLarge`, before decoding. The central directory is walked before the zip parser sees it: bytes without an end record that closes the file exactly (no trailing bytes; the end record is the first signature found scanning back from the end, and a second end signature anywhere in the last 64 KiB plus 22 bytes, such as a fake record in the comment, refuses the package so both parsers agree), zip64 (a locator or an all-ones size or offset field) and multi-disk archives, a directory that does not end exactly at the announced size and count, a bad central record, an over-long name, extra field or comment (1 KiB, in central and local headers), a local header that is missing, and two records sharing one local header are all `notZip`. A hostile directory therefore costs a cheap walk, never the parser's per-record allocations.
- Only stored and deflate entries are read; an unsupported method or an encrypted entry that has to be read, an entry that cannot be inflated, a size or CRC that does not match the data: `notZip`.
- More than 50 entries (folders count): `tooManyEntries`, decided on the end record's count and again while walking, stopping at the 51st record.
- Sum of uncompressed sizes over 5 MiB: `tooLarge`, checked on the declared sizes first and again on what inflating really produces. A header that lies is caught because inflating goes through an output that refuses any byte past the declared size (`tooLarge`); an entry that declares more than it holds is `notZip`. Ignored entries are never inflated. Per entry: script 1 MiB, `plugin.json` 64 KiB.
- Entry names (all entries, kept or not): no absolute path, no `..` segment, no `\`, no drive letter, no NUL; no symlink (Unix `S_IFLNK` in the external attributes); no two names equal ignoring case: `unsafeEntry` with the name.
- No `plugin.json`: `missingManifest`.
- A script that is not valid UTF-8: `scriptError` naming the file. A UTF-8 BOM is stripped from scripts and `plugin.json`.

### `plugin.json`

Unknown fields are ignored. Every length below counts Unicode code points, not UTF-16 units. `author`, `description` (newlines kept) and config titles are cleaned like `name`. Anything wrong in a field is `invalidManifest` with the field path as detail (for example `metadata.name`, `config.cookie.default`).

| Field | Rule |
|---|---|
| `metadata.apiVersion` | int. `1` is supported; greater: `needsNewerApp`; anything else: `invalidManifest` |
| `metadata.type` | must be `"lyrics"`, else `wrongType` |
| `metadata.name` | 1 to 80 code points after control, format (bidi, zero-width, BOM) and line-separator characters are removed and the text is trimmed |
| `metadata.version` | int, 1 to 2147483647 |
| `metadata.hosts` | 1 to 20 strings, trimmed, lower-cased, deduplicated; each must pass `lyricsHostProblem()` (public DNS name only: no IP, `localhost`, single label, `.local`, and the last label must start with a letter, so `127.0.0.0x1` fails). The check is by name only; names that resolve to private addresses are not blocked here (the fetcher must do that at connect time), else `badHost` with the host |
| `metadata.author` | optional, at most 80 characters |
| `metadata.description` | optional, at most 500 characters (newlines kept) |
| `script.search`, `script.lyrics` | file names matching the name pattern above; a name not in `src/` is `missingScript` |
| `config` | optional object, at most 20 fields, kept in order |

Each `config` key matches `^[A-Za-z0-9_]{1,40}$` and has a `title` of 1 to 80 characters and a `mode`:

- `input`: `format` is `text` (default), `number` or `secret`. Optional `default`: a string; for `number` also a finite JSON number or a plain decimal string (`-2.5`, `1e3`; no `NaN`, `Infinity` or hex), stored as text because scripts read config as strings).
- `select`: `format` is absent or `single`. `options` is 1 to 50 items of `{value, title}`, both required, values unique. Optional `default` must be one of the values.
- `toggle`: no `format`. Optional `default` is a boolean.

### Icon

`icon.png` must have the PNG signature, an IHDR chunk, a size of at most 256 x 256 pixels and at most 64 KiB. A bad icon is dropped (the reason is logged, nothing else) and the install goes on; `PluginPackage.icon` is then null.

### Script check

Every kept `src/*.js` goes through `PluginRuntime.check`; the first syntax error is `scriptError` with file, 1-based line (null when unknown) and the engine message. Files are checked in name order, after the manifest and the script names pass. If the runtime cannot check at all (native library missing) the package is refused as `checkUnavailable`, never accepted unchecked.

## Example: the LRCLIB plugin

`test/fixtures/lyrics_plugins/lrclib/` is a complete, commented plugin for [LRCLIB](https://lrclib.net): the same service the built-in Dart provider talks to. It is not installed by default; the tests install it from a zip they build from the folder, and it is the example to copy.

| File | What it does |
|---|---|
| `plugin.json` | `hosts: ["lrclib.net"]`, no `config`; names the two entry scripts |
| `src/common.js` | shared helpers, reached with `load('common.js')`: `lrclibGet(path, queries)` accepts only a 200 JSON answer or LRCLIB's documented `TrackNotFound` 404 and turns everything else into a `Response.error` (429/503 `rateLimited` with `retryAfterSec`, other statuses `server`, wrong content type or JSON `invalidResponse`); `nfc()` sends text in NFC like the Dart provider |
| `src/search.js` | `GET /api/search` with `track_name` and `artist_name`, or `q` for the manual search's `text`; sends `artist_name` only when `artists` has exactly one entry (more than one: `track_name` only, like the Dart provider); maps each record to `{id, title, artist, album, durationMs, lyrics}` like the Dart provider (seconds to milliseconds, a duration of 0 leaves `durationMs` out, a negative or over-a-day duration or a field of the wrong type drops the record, synced text before plain, no `lyrics` for an instrumental record), at most 20 items; a non-empty answer with no usable record is an invalid response |
| `src/lyrics.js` | `GET /api/get/<id>`; returns `null`, `{instrumental: true}` or `{data, type}` with `type` `'lrc'` or `'txt'` |

```js
// src/search.js (excerpt; see the file for the empty-title guard, the artist
// split and the record mapping)
load('common.js');

function execute(input) {
  var queries;
  if (hasText(input.text)) {
    queries = { q: nfc(input.text.trim()) };
  } else {
    var names = artistNames(input.artists);
    queries = {
      track_name: nfc(input.title.trim()),
      artist_name: names.length === 1 ? nfc(names[0]) : undefined,
    };
  }
  var got = lrclibGet('/api/search', queries); // fetch() skips undefined values
  if (got.failure) return got.failure;
  // ... map got.json to items, then:
  return Response.success(items.slice(0, 20));
}
```

Known differences from the Dart provider (pinned by the tests below): a plugin result carries one text, so a record that has both synced and plain lyrics is stored with the synced text only; and a plugin has no exact-match call, so the host runs `search.js` where the Dart provider asks `/api/get` first (an instrumental record, which a search result cannot mark, costs a second request to `lyrics.js`). The sample also leaves out two things the Dart provider does, none of which changes what the app stores: dropping a placeholder artist such as `Unknown Artist` (the plugin would send it as `artist_name`, but the app never runs a structured search for one), and cleaning titles and albums (the app checks plugin results again before it shows or stores them).

### Integration tests

`test/integration/` runs plugins on the real chain: zip, install (with the native syntax check), package loader, native runtime, `fetch` bridge, `LyricsHttp` with its strict host rules, host ranking and the database. Only the network (a loopback server standing in for `https://lrclib.net`) and the secret store are fake. The tests use the `native` tag and need the cargo-built library:

```bash
cargo build --manifest-path rust/Cargo.toml
flutter test test/integration
```

Without `rust/target/debug/librust_lib_kanaru.so` (or with a stale build the bridge cannot load) every test there is reported skipped with that hint.

- `lyrics_plugin_lrclib_test.dart` and `lyrics_plugin_lrclib_unmirrored_test.dart`: the Dart provider and the plugin answer the same fake LRCLIB for a synced song, a plain-only song, an instrumental song and a miss; the stored rows (except `provider_id`) and the manual search's ranked order are compared.
- `lyrics_plugin_hostile_test.dart` and `lyrics_plugin_hostile_slow_test.dart`: the packages in `test/fixtures/lyrics_plugins/hostile/` (endless loop, regex bomb, 64 MiB allocation, deep recursion, 11 fetches, undeclared host, `http://`, a swallowed network error, wrong output shape, 3 MiB output, `load('../x.js')`, console spam) each end as the expected `LyricsFetchKind` (an error the script throws, such as the one `load('../x.js')` throws, is `invalidResponse`), store nothing as "not found", leave one event in the plugin's JSONL log (kind, console, requests without query strings; a config value the script prints or puts in an address appears as `***`) and one INFO line in the app log without song data. The console-spam package is the exception: it is a successful run with an empty answer, so a `not_found` row is stored, the log event is `ok` with the console capped at 50 lines, and the app log gets nothing. Each finishes in under 20 s; the endless loop and the regex bomb wait for the 15 s wall-time limit, so they live in their own file and run in parallel with the others.
