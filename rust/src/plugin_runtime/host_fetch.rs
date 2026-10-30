//! The script's `fetch`: builds the request, hands it to the answerer on the
//! JS thread, waits (cancel and deadline aware) and turns the answer into
//! data the script-side wrapper (`js/host_prelude.js`) shapes into a response
//! object or a named error.
//!
//! Rust checks only what must not cross the boundary: the method and the
//! request body size. Hosts, consent, headers and the response size are
//! judged by the answerer. Error texts made here never contain the URL, the
//! headers, the body or any configuration value.

use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;
use std::sync::atomic::Ordering;

use rquickjs::function::Opt;
use rquickjs::{Coerced, Ctx, Exception, FromJs, Function, Object, Value};

use super::charset;
use super::host::{HostEnv, STOP_CANCELLED, STOP_TIMEOUT};
use super::host_callback::{ask, failed_response, Waited};
use super::limits::{MAX_FETCH_REQUEST_BODY_BYTES, MAX_FETCH_SENDS};
use crate::api::plugin_runtime::{
    PluginFetchFailure, PluginFetchFailureKind as Kind, PluginFetchOutcome as Outcome,
    PluginFetchRequest,
};

/// A response body kept for `text()` / `json()` / `base64()`.
struct Body {
    bytes: Vec<u8>,
    content_type: Option<String>,
}

/// Counters and unread bodies of one call.
#[derive(Default)]
pub struct FetchState {
    /// HTTP sends the answerer reported so far, retries included.
    sends: u32,
    next_id: u32,
    bodies: HashMap<u32, Body>,
}

/// What a script passed in the options object.
struct Parsed {
    method: &'static str,
    headers: Vec<(String, String)>,
    body: Vec<u8>,
    queries: Vec<(String, String)>,
    timeout_ms: Option<f64>,
}

fn type_error<'js>(ctx: &Ctx<'js>, message: &str) -> rquickjs::Error {
    Exception::throw_type(ctx, message)
}

/// Text of a string-ish value; `None` for `undefined` and `null`.
fn coerce<'js>(ctx: &Ctx<'js>, v: Value<'js>) -> rquickjs::Result<Option<String>> {
    if v.is_undefined() || v.is_null() {
        return Ok(None);
    }
    match Coerced::<String>::from_js(ctx, v) {
        Ok(c) => Ok(Some(c.0)),
        Err(e) => Err(string_error(ctx, e)),
    }
}

/// A script's own exception passes through; a failed string conversion (a
/// lone surrogate) becomes a named `TypeError` that echoes nothing.
fn string_error<'js>(ctx: &Ctx<'js>, e: rquickjs::Error) -> rquickjs::Error {
    match e {
        rquickjs::Error::Exception => e,
        _ => type_error(
            ctx,
            "fetch: strings must be well-formed Unicode (no lone surrogates)",
        ),
    }
}

fn string_pairs<'js>(ctx: &Ctx<'js>, v: Value<'js>) -> rquickjs::Result<Vec<(String, String)>> {
    if v.is_undefined() || v.is_null() {
        return Ok(Vec::new());
    }
    let Some(object) = v.into_object() else {
        return Err(type_error(
            ctx,
            "fetch: headers and queries must be objects",
        ));
    };
    let mut out = Vec::new();
    for prop in object.props::<String, Value>() {
        let (key, value) = prop.map_err(|e| string_error(ctx, e))?;
        if let Some(text) = coerce(ctx, value)? {
            out.push((key, text));
        }
    }
    Ok(out)
}

fn parse_options<'js>(ctx: &Ctx<'js>, options: Option<Object<'js>>) -> rquickjs::Result<Parsed> {
    let mut parsed = Parsed {
        method: "GET",
        headers: Vec::new(),
        body: Vec::new(),
        queries: Vec::new(),
        timeout_ms: None,
    };
    let Some(options) = options else {
        return Ok(parsed);
    };
    if let Some(method) = coerce(ctx, options.get("method")?)? {
        parsed.method = match method.to_ascii_uppercase().as_str() {
            "GET" => "GET",
            "POST" => "POST",
            _ => return Err(type_error(ctx, "fetch: method must be GET or POST")),
        };
    }
    parsed.headers = string_pairs(ctx, options.get("headers")?)?;
    parsed.queries = string_pairs(ctx, options.get("queries")?)?;
    let timeout: Value = options.get("timeout")?;
    parsed.timeout_ms = timeout.as_number();

    let body: Value = options.get("body")?;
    if body.is_undefined() || body.is_null() {
        // no body
    } else if let Some(text) = body.as_string() {
        parsed.body = text
            .to_string()
            .map_err(|e| string_error(ctx, e))?
            .into_bytes();
    } else if body.is_object() {
        if let Some(json) = ctx.json_stringify(body)? {
            parsed.body = json
                .to_string()
                .map_err(|e| string_error(ctx, e))?
                .into_bytes();
        }
        let has_type = parsed
            .headers
            .iter()
            .any(|(k, _)| k.eq_ignore_ascii_case("content-type"));
        if !has_type {
            parsed
                .headers
                .push(("content-type".to_owned(), "application/json".to_owned()));
        }
    } else {
        return Err(type_error(ctx, "fetch: body must be a string or an object"));
    }
    Ok(parsed)
}

/// Percent-encodes everything but unreserved characters.
fn percent_encode(s: &str, out: &mut String) {
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'.' | b'_' | b'~') {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{b:02X}"));
        }
    }
}

/// `url` with `queries` appended (before a `#fragment`, after existing queries).
pub fn with_queries(url: &str, queries: &[(String, String)]) -> String {
    if queries.is_empty() {
        return url.to_owned();
    }
    let (base, fragment) = match url.split_once('#') {
        Some((b, f)) => (b, Some(f)),
        None => (url, None),
    };
    let mut out = base.to_owned();
    let mut separator = if base.contains('?') {
        if base.ends_with('?') || base.ends_with('&') {
            ""
        } else {
            "&"
        }
    } else {
        "?"
    };
    for (k, v) in queries {
        out.push_str(separator);
        percent_encode(k, &mut out);
        out.push('=');
        percent_encode(v, &mut out);
        separator = "&";
    }
    if let Some(f) = fragment {
        out.push('#');
        out.push_str(f);
    }
    out
}

/// Script-visible error name and runtime-made message of a failure kind.
fn describe(kind: Kind) -> (&'static str, &'static str) {
    match kind {
        Kind::Network => ("NetworkError", "the network request failed"),
        Kind::BlockedHost => (
            "BlockedHostError",
            "the host is not allowed for this plugin",
        ),
        Kind::NotConsented => (
            "NotConsentedError",
            "the user has not allowed this plugin to use the network",
        ),
        Kind::Abandoned => ("AbortError", "the request was abandoned"),
        Kind::InvalidRequest => ("InvalidRequestError", "the request was refused"),
        Kind::InvalidResponse => ("InvalidResponseError", "the response was refused"),
        Kind::RateLimited => ("RateLimitedError", "the server asked to slow down"),
    }
}

/// Records the sticky failure and returns the `{error, message}` object the
/// wrapper turns into a thrown `Error`.
fn failure<'js>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    kind: Kind,
    name: &str,
    message: &str,
    retry_after_sec: Option<u32>,
) -> rquickjs::Result<Object<'js>> {
    env.collector.set_fetch_failure_once(PluginFetchFailure {
        kind,
        retry_after_sec,
        message: message.to_owned(),
    });
    let object = Object::new(ctx.clone())?;
    object.set("error", name)?;
    object.set("message", message)?;
    if let Some(sec) = retry_after_sec {
        object.set("retryAfterSec", sec)?;
    }
    Ok(object)
}

fn failure_of_kind<'js>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    kind: Kind,
    retry_after_sec: Option<u32>,
) -> rquickjs::Result<Object<'js>> {
    let (name, message) = describe(kind);
    failure(ctx, env, kind, name, message, retry_after_sec)
}

fn kind_of(outcome: Outcome) -> Option<Kind> {
    Some(match outcome {
        Outcome::Ok => return None,
        Outcome::Network => Kind::Network,
        Outcome::BlockedHost => Kind::BlockedHost,
        Outcome::NotConsented => Kind::NotConsented,
        Outcome::Abandoned => Kind::Abandoned,
        Outcome::InvalidRequest => Kind::InvalidRequest,
        Outcome::InvalidResponse => Kind::InvalidResponse,
        Outcome::RateLimited => Kind::RateLimited,
    })
}

fn fetch<'js>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    state: &RefCell<FetchState>,
    url: String,
    options: Option<Object<'js>>,
) -> rquickjs::Result<Object<'js>> {
    let parsed = parse_options(ctx, options)?;
    env.check_alive(ctx)?;
    if parsed.body.len() > MAX_FETCH_REQUEST_BODY_BYTES {
        return failure(
            ctx,
            env,
            Kind::InvalidRequest,
            "InvalidRequestError",
            "the request body is larger than 256 KiB",
            None,
        );
    }
    if state.borrow().sends >= MAX_FETCH_SENDS {
        return failure(
            ctx,
            env,
            Kind::InvalidRequest,
            "TooManyRequestsError",
            "too many requests in one call (limit 10, retries included)",
            None,
        );
    }

    let mut deadline_ms = u32::try_from(env.remaining().as_millis()).unwrap_or(u32::MAX);
    if let Some(t) = parsed.timeout_ms.filter(|t| t.is_finite() && *t >= 1.0) {
        deadline_ms = deadline_ms.min(t.min(f64::from(u32::MAX)) as u32);
    }
    let request = PluginFetchRequest {
        method: parsed.method.to_owned(),
        url: with_queries(&url, &parsed.queries),
        headers: parsed.headers,
        body: parsed.body,
        deadline_ms: deadline_ms.max(1),
    };
    // On this JS thread, never on a bridge worker or the Dart isolate.
    let response = match ask(&env.answerer, request, &env.cancel, env.deadline) {
        Waited::Answer(r) => r,
        // Dart threw: answered as a network failure, like any other.
        Waited::Failed => failed_response(Outcome::Network),
        Waited::Cancelled => return Err(env.stop_error(ctx, STOP_CANCELLED)),
        Waited::DeadlinePassed => return Err(env.stop_error(ctx, STOP_TIMEOUT)),
    };

    // An HTTP exchange happened for these even if the answerer forgot to count.
    let at_least_one = matches!(
        response.outcome,
        Outcome::Ok | Outcome::Network | Outcome::RateLimited | Outcome::InvalidResponse
    );
    let sends = if at_least_one {
        response.sends.max(1)
    } else {
        response.sends
    };
    {
        let mut st = state.borrow_mut();
        st.sends = st.sends.saturating_add(sends);
    }

    if let Some(kind) = kind_of(response.outcome) {
        let retry = (kind == Kind::RateLimited)
            .then_some(response.retry_after_sec)
            .flatten();
        let object = failure_of_kind(ctx, env, kind, retry)?;
        if kind == Kind::Abandoned {
            // The user walked away: the whole job ends `cancelled`, even if the
            // script catches this error.
            env.cancel.store(true, Ordering::SeqCst);
            env.mark_stopped(STOP_CANCELLED);
        }
        return Ok(object);
    }

    let id = {
        let mut st = state.borrow_mut();
        if !env.budget.try_charge(response.body.len()) {
            return Err(Exception::throw_range(
                ctx,
                "fetch: the response bodies kept in memory exceed the limit",
            ));
        }
        st.next_id += 1;
        let id = st.next_id;
        let content_type = response
            .headers
            .iter()
            .find(|(k, _)| k.eq_ignore_ascii_case("content-type"))
            .map(|(_, v)| v.clone());
        st.bodies.insert(
            id,
            Body {
                bytes: response.body,
                content_type,
            },
        );
        id
    };

    // Lower-case names; repeated names are joined with ", ".
    let mut headers: Vec<(String, String)> = Vec::new();
    for (name, value) in response.headers {
        let name = name.to_ascii_lowercase();
        match headers.iter_mut().find(|(k, _)| *k == name) {
            Some((_, existing)) => {
                existing.push_str(", ");
                existing.push_str(&value);
            }
            None => headers.push((name, value)),
        }
    }
    let object = Object::new(ctx.clone())?;
    object.set("id", id)?;
    object.set("status", response.status)?;
    object.set("url", response.url)?;
    // Flat list: name, value, name, value, ...
    let flat: Vec<String> = headers.into_iter().flat_map(|(k, v)| [k, v]).collect();
    object.set("headers", flat)?;
    Ok(object)
}

/// Takes the unread body `id` out of the state (and the budget) after `decode`
/// succeeded on it. A body can be read once; the wrapper caches the result.
fn read_body<'js, T>(
    ctx: &Ctx<'js>,
    env: &HostEnv,
    state: &RefCell<FetchState>,
    id: u32,
    decode: impl FnOnce(&Body) -> Result<T, &'static str>,
) -> rquickjs::Result<T> {
    let mut st = state.borrow_mut();
    let Some(body) = st.bodies.get(&id) else {
        return Err(type_error(ctx, "the body was already read"));
    };
    let value = match decode(body) {
        Ok(v) => v,
        Err(message) => return Err(Exception::throw_range(ctx, message)),
    };
    if let Some(body) = st.bodies.remove(&id) {
        env.budget.release(body.bytes.len());
    }
    Ok(value)
}

/// Standard base64 with padding.
pub fn base64(bytes: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
    for chunk in bytes.chunks(3) {
        let n = (u32::from(chunk[0]) << 16)
            | (u32::from(*chunk.get(1).unwrap_or(&0)) << 8)
            | u32::from(*chunk.get(2).unwrap_or(&0));
        out.push(ALPHABET[(n >> 18) as usize & 63] as char);
        out.push(ALPHABET[(n >> 12) as usize & 63] as char);
        out.push(if chunk.len() > 1 {
            ALPHABET[(n >> 6) as usize & 63] as char
        } else {
            '='
        });
        out.push(if chunk.len() > 2 {
            ALPHABET[n as usize & 63] as char
        } else {
            '='
        });
    }
    out
}

/// Native `fetch`, `bodyText` and `bodyBase64`.
pub fn register<'js>(
    ctx: &Ctx<'js>,
    natives: &Object<'js>,
    env: &Rc<HostEnv>,
) -> rquickjs::Result<()> {
    let state = Rc::new(RefCell::new(FetchState::default()));
    let (e, s) = (env.clone(), state.clone());
    natives.set(
        "fetch",
        Function::new(
            ctx.clone(),
            move |ctx: Ctx<'js>, url: String, options: Opt<Value<'js>>| {
                let options = match options.0 {
                    None => None,
                    Some(v) if v.is_undefined() || v.is_null() => None,
                    Some(v) => match v.into_object() {
                        Some(o) => Some(o),
                        None => return Err(type_error(&ctx, "fetch: options must be an object")),
                    },
                };
                fetch(&ctx, &e, &s, url, options)
            },
        )?,
    )?;
    let (s, e) = (state.clone(), env.clone());
    natives.set(
        "bodyText",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, id: u32, label: String| {
            read_body(&ctx, &e, &s, id, |body| {
                let explicit = (!label.is_empty()).then_some(label.as_str());
                charset::decode(&body.bytes, explicit, body.content_type.as_deref())
                    .ok_or("text: unknown charset")
            })
        })?,
    )?;
    let (s, e) = (state, env.clone());
    natives.set(
        "bodyBase64",
        Function::new(ctx.clone(), move |ctx: Ctx<'js>, id: u32| {
            read_body(&ctx, &e, &s, id, |body| Ok(base64(&body.bytes)))
        })?,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn q(pairs: &[(&str, &str)]) -> Vec<(String, String)> {
        pairs
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect()
    }

    #[test]
    fn queries_are_percent_encoded_and_appended_correctly() {
        assert_eq!(with_queries("https://a.test/x", &[]), "https://a.test/x");
        assert_eq!(
            with_queries("https://a.test/x", &q(&[("q", "a b&c=d/é"), ("n", "1")])),
            "https://a.test/x?q=a%20b%26c%3Dd%2F%C3%A9&n=1"
        );
        assert_eq!(
            with_queries("https://a.test/x?k=v#frag", &q(&[("q", "~-._")])),
            "https://a.test/x?k=v&q=~-._#frag"
        );
        assert_eq!(
            with_queries("https://a.test/x?", &q(&[("a", "b")])),
            "https://a.test/x?a=b"
        );
    }

    #[test]
    fn base64_matches_the_standard_vectors() {
        for (input, want) in [
            ("", ""),
            ("f", "Zg=="),
            ("fo", "Zm8="),
            ("foo", "Zm9v"),
            ("foob", "Zm9vYg=="),
        ] {
            assert_eq!(base64(input.as_bytes()), want);
        }
    }
}
