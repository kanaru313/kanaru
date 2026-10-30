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
| Worker threads | 4 | extra jobs wait |
| Queued jobs | 16 | the 17th waiting job is `busy` |

A timeout and a cancel use an interrupt the script cannot catch, so `try { while (true) {} } catch (e) {}` still stops. Every call gets a fresh engine; globals do not survive between calls.

### Script contract

The entry file (`search.js` or `lyrics.js`) and every file it `load()`s run as **classic global scripts** in one scope, in sloppy mode. There is no module system: `import`, `export` and dynamic `import()` are syntax or runtime errors, and `std`, `os`, `require`, `setTimeout` and `XMLHttpRequest` do not exist. `eval` and `Function` exist (they add no capability). Promises can be created but are never resolved: the host does not run the job queue.

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
- `crypto.js` is reserved for the bundled CryptoJS and cannot be provided by a package.

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

`logs`, `fetch_failure` and `storage_json` are plumbed through every failure path (a per-job collector outlives the script, even a panic). The host APIs that fill them arrive with `fetch`, `console` and `localStorage`; until then they are empty.

Other statuses:

- `cancelled`: `cancel_plugin_job` was called; also returned at once for an unknown, already used or cancelled-before-start job id. A cancel of a running job is seen within about 100 ms; a job still waiting in the queue ends `cancelled` at once and gives its queue slot back.
- `internal`: the runtime failed, not the script: a worker panicked, `input_json` is not valid JSON, the entry file is not in the request, or two files share a name. The next job still runs.
- `busy`: all 4 workers are busy and 16 jobs are waiting. Nothing ran. The host skips this source for the lookup, records no failure and starts no pause.

### Syntax check

`check_plugin_script(name, code)` compiles a file without running it: a top-level `throw` or an endless loop is not executed. It returns `None` when the file parses, else the message and the 1-based line.

### Job ids

`begin_plugin_job()` returns an id, `run_plugin_script` runs under it, `cancel_plugin_job(id)` stops it. An id runs once. Cancelling an id that has not started removes it, so nothing leaks if the run call never comes; cancelling an unknown or finished id does nothing.
