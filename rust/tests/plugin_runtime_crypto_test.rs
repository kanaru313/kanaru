//! `load('crypto.js')`: the bundled CryptoJS 4.2.0 and the calls plugins use.

mod plugin_common;

use plugin_common::run_script;
use rust_lib_kanaru::api::plugin_runtime::{PluginScriptResult, PluginScriptStatus as S};

fn run(body: &str) -> PluginScriptResult {
    run_script(
        &format!("function execute() {{ load('crypto.js'); {body} }}"),
        0,
    )
}

#[test]
fn crypto_is_absent_until_loaded_and_loads_once() {
    let r = run_script(
        "var before = typeof CryptoJS;
         function execute() {
           load('crypto.js'); var first = CryptoJS; load('crypto.js');
           return Response.success([before, typeof CryptoJS, first === CryptoJS,
             typeof module, typeof exports, typeof define]);
         }",
        0,
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"["undefined","object",true,"undefined","undefined","undefined"]"#
    );
}

#[test]
fn md5_sha_and_hmac_have_the_published_values() {
    let r = run("var C = CryptoJS;
         return Response.success([
           C.MD5('abc').toString(),
           C.SHA1('abc').toString(),
           C.SHA256('abc').toString(),
           C.SHA512('abc').toString().slice(0, 32),
           C.HmacSHA256('The quick brown fox jumps over the lazy dog', 'key').toString(),
           C.HmacSHA256('The quick brown fox jumps over the lazy dog', 'key').toString(C.enc.Base64)
         ]);");
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        concat!(
            r#"["900150983cd24fb0d6963f7d28e17f72","#,
            r#""a9993e364706816aba3e25717850c26c9cd0d89d","#,
            r#""ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","#,
            r#""ddaf35a193617abacc417349ae204131","#,
            r#""f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8","#,
            r#""97yD9DBThCSxMpjmqm+xQ+9NWaFJRhdZl0edvC0aPNg="]"#
        )
    );
}

#[test]
fn aes_128_ecb_with_the_eapi_key_matches_openssl_and_round_trips() {
    let r = run(
        "var C = CryptoJS, key = C.enc.Utf8.parse('e82ckenh8dichen8');
         function enc(text) {
           return C.AES.encrypt(text, key, { mode: C.mode.ECB, padding: C.pad.Pkcs7 })
             .ciphertext.toString().toUpperCase();
         }
         function dec(hex) {
           var cipher = C.lib.CipherParams.create({ ciphertext: C.enc.Hex.parse(hex) });
           return C.AES.decrypt(cipher, key, { mode: C.mode.ECB, padding: C.pad.Pkcs7 })
             .toString(C.enc.Utf8);
         }
         var hello = enc('hello world'), json = enc('{\"id\":1}');
         return Response.success([hello, json, dec(hello), dec(json), dec(enc('歌词 é'))]);",
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(
        r.output_json,
        r#"["5AA3F15581585A4011834699FD2472E7","423154B8FA5E30312335DE1A3CCF5B34","hello world","{\"id\":1}","歌词 é"]"#
    );
}

#[test]
fn aes_cbc_encodings_and_hex_base64_round_trip() {
    let r = run(
        "var C = CryptoJS;
         var key = C.enc.Utf8.parse('0123456789abcdef'), iv = C.enc.Utf8.parse('fedcba9876543210');
         var enc = C.AES.encrypt('secret text', key, { iv: iv, mode: C.mode.CBC, padding: C.pad.Pkcs7 });
         var b64 = enc.toString();
         var back = C.AES.decrypt(b64, key, { iv: iv, mode: C.mode.CBC, padding: C.pad.Pkcs7 })
           .toString(C.enc.Utf8);
         return Response.success([back, C.enc.Base64.stringify(C.enc.Utf8.parse('hi')),
           C.enc.Utf8.stringify(C.enc.Base64.parse('aGk=')), C.enc.Hex.stringify(C.enc.Utf8.parse('hi'))]);",
    );
    assert_eq!(r.status, S::Ok, "{r:?}");
    assert_eq!(r.output_json, r#"["secret text","aGk=","hi","6869"]"#);
}

#[test]
fn a_package_file_named_crypto_js_cannot_replace_the_bundled_one() {
    let r = plugin_common::run_files(
        vec![
            plugin_common::file(
                "search.js",
                "function execute() { load('crypto.js'); return Response.success(CryptoJS.MD5('abc').toString()); }",
            ),
            plugin_common::file("crypto.js", "var CryptoJS = { MD5: function () { return 'fake'; } };"),
        ],
        "{}",
    );
    assert_eq!(r.output_json, r#""900150983cd24fb0d6963f7d28e17f72""#);
}
