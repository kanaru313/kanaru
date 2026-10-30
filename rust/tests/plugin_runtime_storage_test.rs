//! `localConfig`, `localStorage` and the console: reads, writes, quota, the
//! changed-map report and the line caps.

mod plugin_common;

use plugin_common::{run_with_fetch, RunOptions};
use rust_lib_kanaru::api::plugin_runtime::{PluginScriptResult, PluginScriptStatus as S};
use rust_lib_kanaru::plugin_runtime::no_network;

fn run(code: &str, config: &[(&str, &str)], storage_json: &str) -> PluginScriptResult {
    run_with_fetch(
        code,
        no_network(),
        RunOptions {
            config: config
                .iter()
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect(),
            storage_json: storage_json.to_owned(),
            timeout_ms: 0,
        },
    )
}

#[test]
fn local_config_returns_the_string_or_null() {
    let r = run(
        "function execute() {
           return Response.success([localConfig.getItem('a'), localConfig.getItem('missing'),
             localConfig.getItem('empty'), localConfig.getItem(5)]);
         }",
        &[("a", "1"), ("empty", ""), ("5", "five")],
        "",
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, r#"["1",null,"","five"]"#);
    assert_eq!(r.storage_json, None);
}

#[test]
fn local_config_is_read_only() {
    let r = run(
        "function execute() {
           try { localConfig.setItem('a', '2'); } catch (e) {}
           try { localConfig.getItem = function () { return 'x'; }; } catch (e) {}
           return Response.success(localConfig.getItem('a'));
         }",
        &[("a", "1")],
        "",
    );
    assert_eq!(r.output_json, r#""1""#);
}

#[test]
fn storage_reads_what_the_host_sent() {
    let r = run(
        "function execute() {
           return Response.success([localStorage.getItem('token'), localStorage.getItem('nope')]);
         }",
        &[],
        r#"{"token":"abc","other":"é"}"#,
    );
    assert_eq!(r.output_json, r#"["abc",null]"#);
    assert_eq!(r.storage_json, None, "nothing changed: nothing to persist");
}

#[test]
fn storage_writes_report_the_whole_new_map() {
    let r = run(
        "function execute() {
           localStorage.setItem('a', '2');
           localStorage.setItem('n', 7);
           localStorage.removeItem('gone');
           localStorage.setItem('q\"', 'line\\nbreak');
           return Response.success([localStorage.getItem('a'), localStorage.getItem('n')]);
         }",
        &[],
        r#"{"a":"1","gone":"x","keep":"k"}"#,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, r#"["2","7"]"#);
    assert_eq!(
        r.storage_json.as_deref(),
        Some(r#"{"a":"2","keep":"k","n":"7","q\"":"line\nbreak"}"#)
    );
}

#[test]
fn writes_that_end_where_they_started_report_nothing() {
    let r = run(
        "function execute() {
           localStorage.setItem('a', 'changed');
           localStorage.setItem('a', '1');
           localStorage.setItem('tmp', 'x');
           localStorage.removeItem('tmp');
           localStorage.removeItem('never-there');
           return Response.success(1);
         }",
        &[],
        r#"{"a":"1"}"#,
    );
    assert_eq!(r.status, S::Ok);
    assert_eq!(r.storage_json, None);
}

#[test]
fn clear_empties_the_map() {
    let r = run(
        "function execute() { localStorage.clear(); return Response.success(localStorage.getItem('a')); }",
        &[],
        r#"{"a":"1"}"#,
    );
    assert_eq!(r.output_json, "null");
    assert_eq!(r.storage_json.as_deref(), Some("{}"));
}

#[test]
fn quota_is_64_kib_of_keys_and_values_and_failure_changes_nothing() {
    let r = run(
        "function execute() {
           var out = [];
           localStorage.setItem('k', 'x'.repeat(40000));
           try { localStorage.setItem('l', 'y'.repeat(30000)); out.push('stored'); }
           catch (e) { out.push(e.name); }
           out.push(localStorage.getItem('l'));
           localStorage.setItem('k', 'z'.repeat(60000));      // overwrite frees the old value
           try { localStorage.setItem('é'.repeat(3000), 'v'); out.push('stored'); }  // 6000 key bytes
           catch (e) { out.push(e.name); }
           return Response.success(out);
         }",
        &[],
        "",
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"["QuotaExceededError",null,"QuotaExceededError"]"#
    );
    let json = r.storage_json.unwrap();
    assert!(
        json.starts_with(r#"{"k":"zzz"#) && json.len() < 64 * 1024 + 20,
        "{}",
        json.len()
    );
}

#[test]
fn storage_survives_in_the_result_when_the_script_then_fails() {
    let r = run(
        "function execute() { localStorage.setItem('seen', 'yes'); throw new Error('after'); }",
        &[],
        "",
    );
    assert_eq!(r.status, S::ScriptError);
    assert_eq!(r.storage_json.as_deref(), Some(r#"{"seen":"yes"}"#));
}

#[test]
fn a_bad_storage_json_is_internal_not_silently_dropped() {
    for bad in ["[1]", "{\"a\":1}", "not json", "\"s\"", "null"] {
        let r = run(
            "function execute() { return Response.success(1); }",
            &[],
            bad,
        );
        assert_eq!(r.status, S::Internal, "{bad}: {r:?}");
        assert!(
            r.error_message.contains("storage_json"),
            "{}",
            r.error_message
        );
    }
    let ok = run(
        "function execute() { return Response.success(1); }",
        &[],
        "  ",
    );
    assert_eq!(ok.status, S::Ok, "blank text means nothing stored");
}

#[test]
fn console_joins_arguments_and_formats_objects() {
    let r = run(
        "function execute() {
           console.log('a', 1, true, null, undefined, {x: [1, 'two']}, [3]);
           console.warn('warn');
           console.error(new Error('boom'));
           console.info('info'); console.debug('debug');
           Log.log('via Log');
           var cyclic = {}; cyclic.self = cyclic;
           console.log(cyclic);
           console.log();
           return Response.success(1);
         }",
        &[],
        "",
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.logs,
        vec![
            "a 1 true null undefined {\"x\":[1,\"two\"]} [3]",
            "warn",
            "Error: boom",
            "info",
            "debug",
            "via Log",
            "[object Object]",
            "",
        ]
    );
}

#[test]
fn console_lines_are_cut_at_500_characters_and_at_50_lines() {
    let r = run(
        "function execute() {
           console.log('é'.repeat(900));
           for (var i = 1; i < 120; i++) console.log('line ' + i);
           return Response.success(1);
         }",
        &[],
        "",
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.logs.len(), 50);
    assert_eq!(r.logs[0].chars().count(), 500);
    assert_eq!(r.logs[1], "line 1");
    assert_eq!(r.logs[48], "line 48");
    assert_eq!(r.logs[49], "… 71 lines dropped"); // 120 lines written, 49 kept
    assert!(r.logs.iter().all(|l| l.chars().count() <= 500));
}

#[test]
fn exactly_fifty_lines_are_all_kept() {
    let r = run(
        "function execute() { for (var i = 0; i < 50; i++) console.log(i); return Response.success(1); }",
        &[],
        "",
    );
    assert_eq!(r.logs.len(), 50);
    assert_eq!(r.logs[49], "49");
}

#[test]
fn a_script_can_declare_its_own_sleep_or_console_helpers() {
    let r = run(
        "function sleep(ms) { return 'mine'; }
         function fetch() { return 'mine too'; }
         var console = { log: function () {} };
         function execute() { console.log('hidden'); return Response.success([sleep(1), fetch()]); }",
        &[],
        "",
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, r#"["mine","mine too"]"#);
    assert!(r.logs.is_empty());
}
