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
| `storage_json` | the plugin's whole new storage map, only when the script changed it |

`logs`, `fetch_failure` and `storage_json` are plumbed through every failure path (a per-job collector outlives the script, even a panic): a `timeout`, `memory` (heap or the Rust byte budget), `stack`, `cancelled`, `outputTooLarge`, `scriptError` or a panicking host callback still returns the console lines written so far, the `js_error` when the engine had one, and the first `fetch` failure. Tests cover each of these.

Other statuses:

- `cancelled`: `cancel_plugin_job` was called; also returned at once for an unknown, already used or cancelled-before-start job id. A cancel of a running job is seen within about 100 ms; a job still waiting in the queue ends `cancelled` at once and gives its queue slot back.
- `internal`: the runtime failed, not the script: a worker panicked, `input_json` is not valid JSON, the entry file is not in the request, or two files share a name. The next job still runs.
- `busy`: all 4 workers are busy and 16 jobs are waiting. Nothing ran. The host skips this source for the lookup, records no failure and starts no pause.

### Syntax check

`check_plugin_script(name, code)` compiles a file without running it: a top-level `throw` or an endless loop is not executed. It returns `None` when the file parses, else the message and the 1-based line.

### Job ids

`begin_plugin_job()` returns an id, `run_plugin_script` runs under it, `cancel_plugin_job(id)` stops it. An id runs once. Cancelling an id that has not started removes it, so nothing leaks if the run call never comes; cancelling an unknown or finished id does nothing.

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
| `BlockedHostError` | the host is not on the plugin's allowlist |
| `NotConsentedError` | the user has not allowed the plugin to use the network |
| `AbortError` | the user stopped the lookup; the call ends `cancelled` even if the script catches this |
| `InvalidRequestError` | the app refused the request (method, headers, body) or the body is over 256 KiB |
| `InvalidResponseError` | the app refused the answer (a body over 4 MiB) |
| `RateLimitedError` | the server asked to slow down; the error has `retryAfterSec` when known |
| `TooManyRequestsError` | the call already used 10 HTTP sends (retries the app made count); nothing is sent |

Error messages made by the runtime are fixed texts: they never contain the URL, headers, body or any `localConfig` value.

**Sticky failure.** The first failing outcome of a call is stored in the result as `fetch_failure` (kind, `retry_after_sec`, text), even when the script catches the error and returns `Response.success([])`, so the app does not cache that as "no lyrics". `TooManyRequestsError` is reported as kind `invalidRequest`.

**Waiting.** The script thread waits for the app until the call's deadline, looking at the cancel flag every 50 ms. An app that never answers ends the call as `timeout`; a callback that throws is answered as `network`; a cancel ends it as `cancelled` within about 100 ms. The request also carries `deadline_ms` (what is left of the call); the app uses the smaller of that and 30 s as the overall timeout.

**Memory.** Response bodies not read yet and parsed `Html` documents are charged to one 16 MiB Rust-side budget per call (the heap cap does not see Rust memory). Responses the script never reads and documents stay charged until the call ends. Going over throws `RangeError` and the call ends with status `memory`, even if the script catches the error and returns normally.

### `sleep(ms)`

Blocks the script thread for `ms` (negative or not a number counts as 0). The time counts toward the call's 15 s: a sleep longer than what is left runs until the deadline and the call ends `timeout`. A cancel interrupts it.

### `localConfig.getItem(key)`

The plugin's configuration as the app set it (secrets included): a string, or `null` when the key is not set. Read-only. The runtime never writes these values to the log or to any message it makes; what a script does with them (for example in `console.log`) is the plugin author's duty.

### `localStorage`

`getItem(key)` (string or `null`), `setItem(key, value)` (both coerced to strings), `removeItem(key)`, `clear()`. The script works on a copy of the plugin's stored map. The quota is 64 KiB of keys plus values (UTF-8 bytes); a `setItem` over it throws `QuotaExceededError` and changes nothing. When the script changed the map, the result's `storage_json` is the whole new map as a JSON object (also when the run failed afterwards); the app writes it back. If two calls of one plugin run at once, the last writer wins. Nothing is returned when the map ended as it started.

### `console` and `Log`

`console.log`, `.info`, `.warn`, `.error`, `.debug` and `Log.log` all write one line: the arguments joined by a space (objects through `JSON.stringify`, falling back to `String()`; an `Error` as `String(error)`). A line is cut at 500 characters. A call keeps at most 50 lines; past that the first 49 are kept and the last entry reads `… N lines dropped`. The lines are returned in `logs`; the app writes them to its log. Do not log secrets or query strings.

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
