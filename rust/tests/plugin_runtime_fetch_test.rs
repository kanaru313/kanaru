//! The script's `fetch`: request building, response objects, error outcomes,
//! the sticky failure, send accounting, waiting, cancel and the memory budget.
//! No test touches the network: an injected answerer plays Dart.

mod plugin_common;

use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use plugin_common::{
    answer_with, block_on, file, never_answers, ok_response, outcome_response, request_with,
    run_with_fetch, RunOptions,
};
use rust_lib_kanaru::api::plugin_runtime::{
    PluginFetchFailureKind as Kind, PluginFetchOutcome as Outcome, PluginFetchRequest,
    PluginScriptResult, PluginScriptStatus as S,
};
use rust_lib_kanaru::plugin_runtime::{self, Answerer};

/// An answerer that records every request and replies with `reply`.
fn recording(
    reply: impl Fn(&PluginFetchRequest) -> rust_lib_kanaru::api::plugin_runtime::PluginFetchResponse
        + Send
        + Sync
        + 'static,
) -> (Answerer, Arc<Mutex<Vec<PluginFetchRequest>>>) {
    let seen = Arc::new(Mutex::new(Vec::new()));
    let log = seen.clone();
    let answerer = answer_with(move |request| {
        let answer = reply(&request);
        log.lock().unwrap().push(request);
        answer
    });
    (answerer, seen)
}

fn run(code: &str, answerer: Answerer) -> PluginScriptResult {
    run_with_fetch(code, answerer, RunOptions::default())
}

fn run_timed(code: &str, answerer: Answerer, timeout_ms: u32) -> PluginScriptResult {
    run_with_fetch(
        code,
        answerer,
        RunOptions {
            timeout_ms,
            ..RunOptions::default()
        },
    )
}

#[test]
fn get_is_the_default_and_queries_are_percent_encoded() {
    let (answerer, seen) = recording(|_| ok_response(200, b"{}"));
    let r = run(
        "function execute() {
           fetch('https://api.test/search?x=1', {queries: {q: 'a b&c=d/é', n: 2, skip: undefined}});
           return Response.success(1);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    let seen = seen.lock().unwrap();
    assert_eq!(seen.len(), 1);
    assert_eq!(seen[0].method, "GET");
    assert_eq!(
        seen[0].url,
        "https://api.test/search?x=1&q=a%20b%26c%3Dd%2F%C3%A9&n=2"
    );
    assert!(seen[0].body.is_empty());
    assert!(seen[0].deadline_ms > 0 && seen[0].deadline_ms <= 15_000);
}

#[test]
fn post_with_a_string_body_and_with_an_object_body() {
    let (answerer, seen) = recording(|_| ok_response(200, b"ok"));
    let r = run(
        "function execute() {
           fetch('https://api.test/a', {method: 'post', body: 'héllo', headers: {'X-Key': 'k', n: 5}});
           fetch('https://api.test/b', {method: 'POST', body: {a: [1, 2], b: 'x'}});
           fetch('https://api.test/c', {method: 'POST', body: {z: 1}, headers: {'Content-Type': 'text/json'}});
           return Response.success(1);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    let seen = seen.lock().unwrap();
    assert_eq!(seen[0].method, "POST");
    assert_eq!(seen[0].body, "héllo".as_bytes());
    assert_eq!(
        seen[0].headers,
        vec![
            ("X-Key".to_owned(), "k".to_owned()),
            ("n".to_owned(), "5".to_owned())
        ]
    );
    assert_eq!(seen[1].body, br#"{"a":[1,2],"b":"x"}"#);
    assert_eq!(
        seen[1].headers,
        vec![("content-type".to_owned(), "application/json".to_owned())]
    );
    assert_eq!(
        seen[2].headers,
        vec![("Content-Type".to_owned(), "text/json".to_owned())],
        "a given content-type is kept, none added"
    );
}

#[test]
fn another_method_or_body_type_is_a_type_error_and_never_reaches_dart() {
    let (answerer, seen) = recording(|_| ok_response(200, b""));
    let r = run(
        "function execute() {
           var names = [];
           ['PUT', 'DELETE', 'HEAD', 5].forEach(function (m) {
             try { fetch('https://api.test/', {method: m}); } catch (e) { names.push(e.name); }
           });
           try { fetch('https://api.test/', {body: 42}); } catch (e) { names.push(e.name); }
           try { fetch('https://api.test/', 'oops'); } catch (e) { names.push(e.name); }
           return Response.success(names);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"["TypeError","TypeError","TypeError","TypeError","TypeError","TypeError"]"#
    );
    assert!(seen.lock().unwrap().is_empty());
    assert_eq!(
        r.fetch_failure, None,
        "a bad call is a script bug, not a fetch failure"
    );
}

#[test]
fn response_object_has_status_url_lowercase_headers_and_header_lookup() {
    let (answerer, _) = recording(|_| {
        let mut r = ok_response(201, b"{\"a\":1}");
        r.headers = vec![
            ("Content-Type".to_owned(), "application/json".to_owned()),
            ("X-Multi".to_owned(), "one".to_owned()),
            ("x-multi".to_owned(), "two".to_owned()),
        ];
        r
    });
    let r = run(
        "function execute() {
           var res = fetch('https://api.test/');
           return Response.success({
             status: res.status, ok: res.ok, url: res.url,
             type: res.headers['content-type'], multi: res.headers['x-multi'],
             viaHeader: res.header('X-MULTI'), missing: res.header('nope'),
             keys: Object.keys(res.headers), json: res.json()
           });
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"{"status":201,"ok":true,"url":"https://example.test/final","type":"application/json","multi":"one, two","viaHeader":"one, two","missing":null,"keys":["content-type","x-multi"],"json":{"a":1}}"#
    );
}

#[test]
fn ok_is_false_outside_200_to_299() {
    let (answerer, _) = recording(|_| ok_response(404, b""));
    let r = run(
        "function execute() { var r = fetch('https://api.test/'); return Response.success([r.status, r.ok]); }",
        answerer,
    );
    assert_eq!(r.output_json, "[404,false]");
    assert_eq!(
        r.fetch_failure, None,
        "an HTTP error status is not a failed outcome"
    );
}

#[test]
fn text_decodes_by_argument_then_content_type_then_utf8() {
    let gbk = encoding_rs::GBK.encode("你好，歌词").0.into_owned();
    let big5 = encoding_rs::BIG5.encode("歌詞").0.into_owned();
    let gbk_body = gbk.clone();
    let (answerer, _) = recording(move |request| {
        let mut r = ok_response(200, b"");
        match request.url.rsplit('/').next().unwrap() {
            "gbk" => r.body = gbk_body.clone(),
            "big5" => {
                r.body = big5.clone();
                r.headers = vec![(
                    "Content-Type".to_owned(),
                    "text/html; charset=big5".to_owned(),
                )];
            }
            "utf8" => r.body = "kết".as_bytes().to_vec(),
            "bad" => r.body = b"a\xffb".to_vec(),
            _ => {}
        }
        r
    });
    let r = run(
        "function execute() {
           var out = [];
           out.push(fetch('https://t.test/gbk').text('gbk'));
           out.push(fetch('https://t.test/gbk').text('GB18030'));
           out.push(fetch('https://t.test/big5').text());
           out.push(fetch('https://t.test/utf8').text());
           out.push(fetch('https://t.test/bad').text());
           var unknown;
           try { fetch('https://t.test/utf8').text('klingon'); } catch (e) { unknown = e.name; }
           out.push(unknown);
           return Response.success(out);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"["你好，歌词","你好，歌词","歌詞","kết","a�b","RangeError"]"#
            .replace("\\ufffd", "\u{fffd}")
    );
}

#[test]
fn json_failure_is_a_syntax_error_and_text_is_read_once_then_cached() {
    let (answerer, _) = recording(|_| ok_response(200, b"<html>"));
    let r = run(
        "function execute() {
           var res = fetch('https://t.test/');
           var name;
           try { res.json(); } catch (e) { name = e.name; }
           return Response.success([name, res.text(), res.text('gbk')]);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, r#"["SyntaxError","<html>","<html>"]"#);
}

#[test]
fn base64_and_mixing_text_with_base64() {
    let (answerer, _) = recording(|_| ok_response(200, &[0xfb, 0xff, 0x00, 0x41]));
    let r = run(
        "function execute() {
           var a = fetch('https://t.test/'), b = fetch('https://t.test/');
           var out = [a.base64(), a.base64()];
           try { a.text(); } catch (e) { out.push(e.message); }
           b.text();
           try { b.base64(); } catch (e) { out.push(e.message); }
           return Response.success(out);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"["+/8AQQ==","+/8AQQ==","the body was already read as base64","the body was already read as text"]"#
    );
}

#[test]
fn every_failing_outcome_throws_its_named_error_and_sets_the_sticky_failure() {
    let cases = [
        (Outcome::Network, "NetworkError", Kind::Network),
        (Outcome::BlockedHost, "BlockedHostError", Kind::BlockedHost),
        (
            Outcome::NotConsented,
            "NotConsentedError",
            Kind::NotConsented,
        ),
        (
            Outcome::InvalidRequest,
            "InvalidRequestError",
            Kind::InvalidRequest,
        ),
        (
            Outcome::InvalidResponse,
            "InvalidResponseError",
            Kind::InvalidResponse,
        ),
        (Outcome::RateLimited, "RateLimitedError", Kind::RateLimited),
    ];
    for (outcome, name, kind) in cases {
        let (answerer, _) = recording(move |_| outcome_response(outcome));
        let r = run(
            "function execute() {
               try { fetch('https://t.test/'); } catch (e) { return Response.success([e.name, e instanceof Error]); }
               return Response.success('no throw');
             }",
            answerer,
        );
        assert_eq!(r.status, S::Ok, "{name}: {r:?}");
        assert_eq!(r.output_json, format!("[\"{name}\",true]"));
        let failure = r.fetch_failure.expect(name);
        assert_eq!(failure.kind, kind, "{name}");
        assert!(!failure.message.is_empty());
    }
}

#[test]
fn rate_limited_carries_retry_after_on_the_error_and_the_failure() {
    let (answerer, _) = recording(|_| {
        let mut r = outcome_response(Outcome::RateLimited);
        r.retry_after_sec = Some(42);
        r
    });
    let r = run(
        "function execute() {
           try { fetch('https://t.test/'); } catch (e) { return Response.success(e.retryAfterSec); }
         }",
        answerer,
    );
    assert_eq!(r.output_json, "42");
    let failure = r.fetch_failure.unwrap();
    assert_eq!(
        (failure.kind, failure.retry_after_sec),
        (Kind::RateLimited, Some(42))
    );
}

#[test]
fn a_caught_network_error_still_leaves_the_failure_and_only_the_first_counts() {
    let calls = Arc::new(AtomicU32::new(0));
    let counter = calls.clone();
    let answerer = answer_with(move |_| {
        if counter.fetch_add(1, Ordering::SeqCst) == 0 {
            outcome_response(Outcome::Network)
        } else {
            outcome_response(Outcome::BlockedHost)
        }
    });
    let r = run(
        "function execute() {
           try { fetch('https://t.test/'); } catch (e) {}
           try { fetch('https://t.test/'); } catch (e) {}
           return Response.success([]);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok);
    assert_eq!(r.output_json, "[]");
    assert_eq!(r.fetch_failure.unwrap().kind, Kind::Network);
}

#[test]
fn abandoned_ends_the_job_cancelled_even_when_the_script_catches_it() {
    let (answerer, _) = recording(|_| outcome_response(Outcome::Abandoned));
    let r = run(
        "function execute() {
           console.log('before');
           try { fetch('https://t.test/'); } catch (e) { console.log(e.name); }
           return Response.success(['looks fine']);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Cancelled, "{r:?}");
    assert_eq!(r.fetch_failure.unwrap().kind, Kind::Abandoned);
    assert_eq!(r.logs, vec!["before".to_owned(), "AbortError".to_owned()]);
}

#[test]
fn the_send_budget_counts_retries_and_the_next_fetch_is_refused() {
    // Each answer used 4 sends (retries inside): the third fetch would be the 9th..12th.
    let calls = Arc::new(AtomicU32::new(0));
    let counter = calls.clone();
    let answerer = answer_with(move |_| {
        counter.fetch_add(1, Ordering::SeqCst);
        let mut r = ok_response(200, b"x");
        r.sends = 4;
        r
    });
    let r = run(
        "function execute() {
           var out = [];
           for (var i = 0; i < 5; i++) {
             try { fetch('https://t.test/'); out.push('ok'); } catch (e) { out.push(e.name); }
           }
           return Response.success(out);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    // 4 + 4 = 8 < 10 allows a third; 12 >= 10 refuses the rest.
    assert_eq!(
        r.output_json,
        r#"["ok","ok","ok","TooManyRequestsError","TooManyRequestsError"]"#
    );
    assert_eq!(calls.load(Ordering::SeqCst), 3);
    assert_eq!(r.fetch_failure.unwrap().kind, Kind::InvalidRequest);
}

#[test]
fn ten_plain_fetches_pass_and_the_eleventh_is_refused() {
    let (answerer, seen) = recording(|_| ok_response(200, b"x"));
    let r = run(
        "function execute() {
           var n = 0, err = null;
           for (var i = 0; i < 11; i++) {
             try { fetch('https://t.test/'); n++; } catch (e) { err = e.name; }
           }
           return Response.success([n, err]);
         }",
        answerer,
    );
    assert_eq!(r.output_json, r#"[10,"TooManyRequestsError"]"#);
    assert_eq!(seen.lock().unwrap().len(), 10);
}

#[test]
fn an_answer_that_forgets_to_count_still_costs_one_send() {
    let answerer = answer_with(|_| {
        let mut r = ok_response(200, b"x");
        r.sends = 0;
        r
    });
    let r = run(
        "function execute() {
           var n = 0;
           for (var i = 0; i < 20; i++) { try { fetch('https://t.test/'); n++; } catch (e) {} }
           return Response.success(n);
         }",
        answerer,
    );
    assert_eq!(r.output_json, "10");
}

#[test]
fn a_request_body_over_256_kib_is_refused_before_it_crosses() {
    let (answerer, seen) = recording(|_| ok_response(200, b""));
    let r = run(
        "function execute() {
           var big = 'x'.repeat(256 * 1024 + 1), name;
           try { fetch('https://t.test/', {method: 'POST', body: big}); } catch (e) { name = e.name; }
           fetch('https://t.test/', {method: 'POST', body: 'x'.repeat(256 * 1024)});
           return Response.success(name);
         }",
        answerer,
    );
    assert_eq!(r.output_json, r#""InvalidRequestError""#);
    assert_eq!(
        seen.lock().unwrap().len(),
        1,
        "only the body at the limit went through"
    );
    assert_eq!(r.fetch_failure.unwrap().kind, Kind::InvalidRequest);
}

#[test]
fn deadline_ms_is_what_is_left_of_the_call_or_the_script_timeout_if_smaller() {
    let (answerer, seen) = recording(|_| ok_response(200, b""));
    let r = run_timed(
        "function execute() {
           fetch('https://t.test/');
           fetch('https://t.test/', {timeout: 500});
           fetch('https://t.test/', {timeout: 600000});
           fetch('https://t.test/', {timeout: -5});
           return Response.success(1);
         }",
        answerer,
        8_000,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    let seen = seen.lock().unwrap();
    let ms: Vec<u32> = seen.iter().map(|q| q.deadline_ms).collect();
    assert!(ms[0] <= 8_000 && ms[0] > 5_000, "{ms:?}");
    assert!(ms[1] <= 500 && ms[1] > 400, "{ms:?}");
    assert!(
        ms[2] <= 8_000 && ms[2] > 7_000,
        "clamped to what is left: {ms:?}"
    );
    assert!(
        ms[3] <= 8_000 && ms[3] > 7_000,
        "a bad timeout is ignored: {ms:?}"
    );
}

#[test]
fn fetch_runs_on_a_plugin_js_worker_never_on_the_calling_or_a_bridge_thread() {
    let names = Arc::new(Mutex::new(Vec::new()));
    let log = names.clone();
    let answerer = answer_with(move |_| {
        let t = thread::current();
        log.lock()
            .unwrap()
            .push((t.id(), t.name().map(str::to_owned)));
        ok_response(200, b"")
    });
    let r = run(
        "function execute() { fetch('https://t.test/'); return Response.success(1); }",
        answerer,
    );
    assert_eq!(r.status, S::Ok);
    let names = names.lock().unwrap();
    assert_eq!(names.len(), 1);
    let (id, name) = &names[0];
    assert_ne!(
        *id,
        thread::current().id(),
        "not the thread that awaits the result"
    );
    assert!(
        name.as_deref().is_some_and(|n| n.starts_with("plugin-js-")),
        "called on {name:?}"
    );
}

#[test]
fn a_dart_side_that_never_answers_ends_the_job_as_timeout() {
    let started = Instant::now();
    let r = run_timed(
        "function execute() { console.log('waiting'); fetch('https://t.test/'); return Response.success(1); }",
        never_answers(),
        300,
    );
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert!(started.elapsed() < Duration::from_secs(5));
    assert_eq!(r.logs, vec!["waiting".to_owned()]);
    assert!(r.error_message.contains("300 ms"), "{}", r.error_message);
}

#[test]
fn a_script_that_catches_the_timeout_is_still_a_timeout() {
    let r = run_timed(
        "function execute() {
           try { fetch('https://t.test/'); } catch (e) {}
           return Response.success('late but fine');
         }",
        never_answers(),
        200,
    );
    assert_eq!(r.status, S::Timeout, "{r:?}");
}

#[test]
fn cancel_while_waiting_for_dart_ends_cancelled_quickly() {
    let job = plugin_runtime::begin_job();
    let canceller = thread::spawn(move || {
        thread::sleep(Duration::from_millis(200));
        let at = Instant::now();
        plugin_runtime::cancel_job(job);
        at
    });
    let request = request_with(
        job,
        vec![file(
            "search.js",
            "function execute() { console.log('sent'); try { fetch('https://t.test/'); } catch (e) {} return Response.success(1); }",
        )],
        "{}",
        0,
    );
    let r = block_on(plugin_runtime::run_with(request, never_answers()));
    let finished = Instant::now();
    let cancelled_at = canceller.join().unwrap();
    assert_eq!(r.status, S::Cancelled, "{r:?}");
    assert!(
        finished.duration_since(cancelled_at) < Duration::from_millis(1_800),
        "cancel took {:?}",
        finished.duration_since(cancelled_at)
    );
    assert_eq!(r.logs, vec!["sent".to_owned()]);
}

#[test]
fn bodies_held_unread_count_against_a_rust_budget_and_overrun_is_memory() {
    // 5 MiB each, kept unread: the 4th pushes the total past 16 MiB.
    let answerer = answer_with(|_| ok_response(200, &vec![b'x'; 5 * 1024 * 1024]));
    let r = run(
        "function execute() {
           console.log('start');
           var kept = [];
           for (var i = 0; i < 6; i++) { kept.push(fetch('https://t.test/')); console.log('got ' + i); }
           return Response.success(kept.length);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs, vec!["start", "got 0", "got 1", "got 2"]);
    let js = r.js_error.expect("the RangeError");
    assert!(js.message.contains("exceed the limit"), "{js:?}");
}

#[test]
fn reading_a_body_releases_its_share_of_the_budget() {
    let answerer = answer_with(|_| ok_response(200, &vec![b'y'; 5 * 1024 * 1024]));
    let r = run(
        "function execute() {
           var total = 0;
           for (var i = 0; i < 9; i++) { total += fetch('https://t.test/').base64().length > 0 ? 1 : 0; }
           return Response.success(total);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, "9");
}

#[test]
fn runtime_made_errors_never_contain_config_values() {
    const SECRET: &str = "s3cr3t-token-value";
    let cases = [
        Outcome::Network,
        Outcome::BlockedHost,
        Outcome::NotConsented,
        Outcome::Abandoned,
        Outcome::InvalidRequest,
        Outcome::InvalidResponse,
        Outcome::RateLimited,
    ];
    // The secret is used everywhere a script can put it: query, header, body, url.
    let script = format!(
        "function execute() {{
           var key = localConfig.getItem('apiKey');
           var texts = [];
           function grab(f) {{ try {{ f(); }} catch (e) {{ texts.push(e.name + ': ' + e.message); }} }}
           grab(function () {{ fetch('https://t.test/' + key, {{queries: {{k: key}}, headers: {{'X-Key': key}}}}); }});
           grab(function () {{ fetch('https://t.test/', {{method: key}}); }});
           grab(function () {{ fetch('https://t.test/', {{method: 'POST', body: key.repeat(30000)}}); }});
           grab(function () {{ fetch('https://t.test/', {{body: key}}).text(key); }});
           return Response.success(texts);
         }}"
    );
    for outcome in cases {
        let (answerer, _) = recording(move |_| outcome_response(outcome));
        let r = run_with_fetch(
            &script,
            answerer,
            RunOptions {
                config: vec![("apiKey".to_owned(), SECRET.to_owned())],
                ..RunOptions::default()
            },
        );
        let everything = format!("{r:?}");
        assert!(
            r.status == S::Ok || r.status == S::Cancelled,
            "{outcome:?}: {r:?}"
        );
        // For a cancelled run the output is empty; the failure text is still checked.
        assert!(
            !everything.contains(SECRET),
            "{outcome:?}: a config value leaked into runtime text: {everything}"
        );
    }
    // And the texts the script did get contain the secret nowhere either.
    let (answerer, _) = recording(|_| outcome_response(Outcome::Network));
    let r = run_with_fetch(
        &script,
        answerer,
        RunOptions {
            config: vec![("apiKey".to_owned(), SECRET.to_owned())],
            ..RunOptions::default()
        },
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert!(!r.output_json.contains(SECRET), "{}", r.output_json);
    assert!(r.output_json.contains("NetworkError"), "{}", r.output_json);
}

#[test]
fn network_apis_and_module_loaders_do_not_exist() {
    let (answerer, _) = recording(|_| ok_response(200, b""));
    let r = run(
        "function execute() {
           return Response.success([typeof XMLHttpRequest, typeof WebSocket, typeof require,
             typeof setTimeout, typeof setInterval, typeof process, typeof Html, typeof fetch,
             typeof sleep, typeof localStorage, typeof localConfig, typeof console, typeof Log]);
         }",
        answerer,
    );
    assert_eq!(
        r.output_json,
        r#"["undefined","undefined","undefined","undefined","undefined","undefined","object","function","function","object","object","object","object"]"#
    );
}

#[test]
fn sleep_waits_and_counts_toward_the_wall_time() {
    let (answerer, _) = recording(|_| ok_response(200, b""));
    let started = Instant::now();
    let r = run_timed(
        "function execute() { sleep(150); sleep(-1); sleep(NaN); sleep('x'); return Response.success(1); }",
        answerer.clone(),
        0,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert!(started.elapsed() >= Duration::from_millis(150));

    // Asking for more than what is left ends the call as a timeout at the deadline.
    let started = Instant::now();
    let r = run_timed(
        "function execute() { console.log('a'); sleep(60000); return Response.success(1); }",
        answerer.clone(),
        300,
    );
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert!(started.elapsed() < Duration::from_secs(5));
    assert_eq!(r.logs, vec!["a".to_owned()]);

    // Several sleeps add up.
    let r = run_timed(
        "function execute() { for (var i = 0; i < 100; i++) sleep(50); return Response.success(1); }",
        answerer,
        400,
    );
    assert_eq!(r.status, S::Timeout, "{r:?}");
}

#[test]
fn cancel_during_sleep_ends_cancelled_quickly() {
    let job = plugin_runtime::begin_job();
    let canceller = thread::spawn(move || {
        thread::sleep(Duration::from_millis(200));
        let at = Instant::now();
        plugin_runtime::cancel_job(job);
        at
    });
    let request = request_with(
        job,
        vec![file(
            "search.js",
            "function execute() { console.log('zzz'); sleep(10000); return Response.success(1); }",
        )],
        "{}",
        0,
    );
    let r = block_on(plugin_runtime::run_with(request, never_answers()));
    let finished = Instant::now();
    let cancelled_at = canceller.join().unwrap();
    assert_eq!(r.status, S::Cancelled, "{r:?}");
    assert!(finished.duration_since(cancelled_at) < Duration::from_millis(1_800));
    assert_eq!(r.logs, vec!["zzz".to_owned()]);
}

#[test]
fn a_run_without_an_answerer_fails_fetches_with_network() {
    let r = block_on(plugin_runtime::run(request_with(
        plugin_runtime::begin_job(),
        vec![file(
            "search.js",
            "function execute() { try { fetch('https://t.test/'); } catch (e) { return Response.success(e.name); } }",
        )],
        "{}",
        0,
    )));
    assert_eq!(r.output_json, r#""NetworkError""#);
    assert_eq!(r.fetch_failure.unwrap().kind, Kind::Network);
}

#[test]
fn a_throwing_dart_callback_is_answered_as_network_and_the_failure_sticks() {
    for panic_at_call in [true, false] {
        let answerer: Answerer = Arc::new(move |_request| {
            if panic_at_call {
                panic!("dart threw at call")
            }
            Box::pin(async { panic!("dart threw in poll") })
        });
        let r = run(
            "function execute() {
               try { fetch('https://t.test/?k=secret'); } catch (e) { console.log(e.name); }
               return Response.success([]);
             }",
            answerer,
        );
        assert_eq!(r.status, S::Ok, "{r:?}");
        assert_eq!(r.logs, vec!["NetworkError".to_owned()]);
        let failure = r.fetch_failure.as_ref().expect("sticky failure");
        assert_eq!(failure.kind, Kind::Network);
        assert!(!format!("{r:?}").contains("dart threw"));
    }
}

/// A future that completes only when told to and records when it is dropped.
struct LateFuture {
    release: Arc<std::sync::atomic::AtomicBool>,
    completed: Arc<std::sync::atomic::AtomicBool>,
    dropped: Arc<std::sync::atomic::AtomicBool>,
}

impl std::future::Future for LateFuture {
    type Output = rust_lib_kanaru::api::plugin_runtime::PluginFetchResponse;
    fn poll(
        self: std::pin::Pin<&mut Self>,
        _cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Self::Output> {
        if self.release.load(Ordering::SeqCst) {
            self.completed.store(true, Ordering::SeqCst);
            std::task::Poll::Ready(ok_response(200, b"late body"))
        } else {
            std::task::Poll::Pending
        }
    }
}

impl Drop for LateFuture {
    fn drop(&mut self) {
        self.dropped.store(true, Ordering::SeqCst);
    }
}

#[test]
fn an_answer_that_arrives_after_the_job_ended_is_drained_not_dropped() {
    use std::sync::atomic::AtomicBool;
    let flag = || Arc::new(AtomicBool::new(false));
    let (release, completed, dropped) = (flag(), flag(), flag());
    let (r2, c2, d2) = (release.clone(), completed.clone(), dropped.clone());
    let answerer: Answerer = Arc::new(move |_request| {
        Box::pin(LateFuture {
            release: r2.clone(),
            completed: c2.clone(),
            dropped: d2.clone(),
        })
    });
    let r = run_timed(
        "function execute() { fetch('https://t.test/?k=secret'); return Response.success(1); }",
        answerer,
        200,
    );
    assert_eq!(r.status, S::Timeout, "{r:?}");
    assert!(
        !dropped.load(Ordering::SeqCst),
        "a pending future is never dropped on the JS thread"
    );
    release.store(true, Ordering::SeqCst);
    let end = Instant::now() + Duration::from_secs(5);
    while !dropped.load(Ordering::SeqCst) && Instant::now() < end {
        thread::sleep(Duration::from_millis(20));
    }
    assert!(
        completed.load(Ordering::SeqCst),
        "the drain polled it to completion"
    );
    assert!(
        dropped.load(Ordering::SeqCst),
        "and freed it only after it finished"
    );
}

#[test]
fn a_caught_byte_budget_overrun_still_ends_memory() {
    let answerer = answer_with(|_| ok_response(200, &vec![b'x'; 5 * 1024 * 1024]));
    let r = run(
        "function execute() {
           var kept = [], caught = null;
           for (var i = 0; i < 6; i++) {
             try { kept.push(fetch('https://t.test/')); } catch (e) { caught = e.name; }
           }
           console.log('caught ' + caught);
           return Response.success('looks fine');
         }",
        answerer,
    );
    assert_eq!(r.status, S::Memory, "{r:?}");
    assert_eq!(r.logs, vec!["caught RangeError".to_owned()]);
}

#[test]
fn an_unrelated_error_without_an_overrun_is_not_memory() {
    let answerer = answer_with(|_| ok_response(200, &vec![b'x'; 5 * 1024 * 1024]));
    let r = run(
        "function execute() { fetch('https://t.test/'); fetch('https://t.test/'); throw new Error('plain'); }",
        answerer,
    );
    assert_eq!(r.status, S::ScriptError, "{r:?}");
}

#[test]
fn lone_surrogates_never_reach_rust_as_a_raw_conversion_error() {
    let (answerer, seen) = recording(|_| ok_response(200, b"x"));
    let r = run(
        "function execute() {
           var names = [];
           function grab(f) { try { f(); } catch (e) { names.push(e.name); } }
           grab(function () { fetch('https://t.test/' + 'a\\uD800b'); });
           grab(function () { fetch('https://t.test/', {queries: {q: 'a\\uD800b'}}); });
           grab(function () { fetch('https://t.test/', {headers: {h: 'a\\uD800b'}}); });
           grab(function () { fetch('https://t.test/', {method: 'POST', body: 'a\\uD800b'}); });
           grab(function () { localStorage.setItem('k', 'a\\uD800b'); });
           grab(function () { localConfig.getItem('a\\uD800b'); });
           console.log('a\\uD800b');
           console.log('x'.repeat(3998) + '\\uD83D\\uDE00' + 'tail');
           return Response.success(names);
         }",
        answerer,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"["TypeError","TypeError","TypeError","TypeError","TypeError","TypeError"]"#
    );
    assert!(seen.lock().unwrap().is_empty());
    assert_eq!(r.logs.len(), 2);
    assert_eq!(r.logs[0], "a\u{fffd}b");
    assert_eq!(r.logs[1].chars().count(), 500);
}
