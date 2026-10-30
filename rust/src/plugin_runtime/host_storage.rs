//! `localStorage` for one call: a copy of the plugin's stored map with a
//! quota, and the check whether the script changed it. `localConfig` is a
//! plain read-only map held by the host environment.

use std::collections::BTreeMap;

use rquickjs::{Ctx, Exception, Function, Object, Value};

use super::host::HostEnv;
use super::limits::STORAGE_QUOTA_BYTES;

/// The plugin's string-to-string storage during one call.
#[derive(Default)]
pub struct Storage {
    map: BTreeMap<String, String>,
    initial: BTreeMap<String, String>,
    /// Keys plus values of `map`, UTF-8 bytes.
    bytes: usize,
}

fn size_of(map: &BTreeMap<String, String>) -> usize {
    map.iter().map(|(k, v)| k.len() + v.len()).sum()
}

impl Storage {
    /// Replaces the contents with what the host sent. Not checked against the
    /// quota: only the script's own writes are.
    pub fn load(&mut self, entries: BTreeMap<String, String>) {
        self.bytes = size_of(&entries);
        self.initial = entries.clone();
        self.map = entries;
    }

    pub fn get(&self, key: &str) -> Option<String> {
        self.map.get(key).cloned()
    }

    /// Stores `value`; false (nothing changed) when the quota would be exceeded.
    pub fn set(&mut self, key: String, value: String) -> bool {
        let old = self.map.get(&key).map_or(0, |v| key.len() + v.len());
        let new_bytes = self.bytes - old + key.len() + value.len();
        if new_bytes > STORAGE_QUOTA_BYTES {
            return false;
        }
        self.bytes = new_bytes;
        self.map.insert(key, value);
        true
    }

    pub fn remove(&mut self, key: &str) {
        if let Some(v) = self.map.remove(key) {
            self.bytes -= key.len() + v.len();
        }
    }

    pub fn clear(&mut self) {
        self.map.clear();
        self.bytes = 0;
    }

    /// The whole map as a JSON object, only when it differs from what was loaded.
    pub fn changed_json(&self) -> Option<String> {
        (self.map != self.initial).then(|| to_json(&self.map))
    }
}

/// Reads the request's `storage_json` (empty text means an empty map) into the
/// collector's storage. Anything but an object of strings is refused: Dart
/// wrote it, so a bad value is a bug to see, not data to drop.
fn load_initial<'js>(ctx: &Ctx<'js>, env: &HostEnv) -> rquickjs::Result<()> {
    let bad = || {
        Exception::throw_message(
            ctx,
            "storage_json must be a JSON object whose values are all strings",
        )
    };
    let mut entries = BTreeMap::new();
    if !env.storage_json.trim().is_empty() {
        let value = ctx
            .json_parse(env.storage_json.as_str())
            .map_err(|_| bad())?;
        let object = value.into_object().ok_or_else(bad)?;
        for prop in object.props::<String, Value>() {
            let (key, value) = prop?;
            let text = value.as_string().ok_or_else(bad)?.to_string()?;
            entries.insert(key, text);
        }
    }
    env.collector.with_storage(|s| s.load(entries));
    Ok(())
}

/// Native `storageGet/Set/Remove/Clear` and `configGet`.
pub fn register<'js>(
    ctx: &Ctx<'js>,
    natives: &Object<'js>,
    env: &std::rc::Rc<HostEnv>,
) -> rquickjs::Result<()> {
    load_initial(ctx, env)?;
    let e = env.clone();
    natives.set(
        "storageGet",
        Function::new(ctx.clone(), move |key: String| {
            e.collector.with_storage(|s| s.get(&key))
        })?,
    )?;
    let e = env.clone();
    natives.set(
        "storageSet",
        Function::new(ctx.clone(), move |key: String, value: String| {
            e.collector.with_storage(|s| s.set(key, value))
        })?,
    )?;
    let e = env.clone();
    natives.set(
        "storageRemove",
        Function::new(ctx.clone(), move |key: String| {
            e.collector.with_storage(|s| s.remove(&key))
        })?,
    )?;
    let e = env.clone();
    natives.set(
        "storageClear",
        Function::new(ctx.clone(), move || e.collector.with_storage(|s| s.clear()))?,
    )?;
    let e = env.clone();
    natives.set(
        "configGet",
        Function::new(ctx.clone(), move |key: String| e.config.get(&key).cloned())?,
    )
}

/// JSON object text of a string map (keys sorted).
fn to_json(map: &BTreeMap<String, String>) -> String {
    let mut out = String::from("{");
    for (n, (k, v)) in map.iter().enumerate() {
        if n > 0 {
            out.push(',');
        }
        push_json_string(&mut out, k);
        out.push(':');
        push_json_string(&mut out, v);
    }
    out.push('}');
    out
}

fn push_json_string(out: &mut String, s: &str) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
}

#[cfg(test)]
mod tests {
    use super::*;

    fn loaded(pairs: &[(&str, &str)]) -> Storage {
        let mut s = Storage::default();
        s.load(
            pairs
                .iter()
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect(),
        );
        s
    }

    #[test]
    fn unchanged_or_restored_map_has_no_json() {
        let mut s = loaded(&[("a", "1")]);
        assert_eq!(s.changed_json(), None);
        s.set("a".into(), "2".into());
        assert!(s.changed_json().is_some());
        s.set("a".into(), "1".into());
        assert_eq!(s.changed_json(), None);
        s.clear();
        assert_eq!(s.changed_json().as_deref(), Some("{}"));
    }

    #[test]
    fn quota_counts_keys_and_values_and_frees_on_overwrite() {
        let mut s = Storage::default();
        let half = "x".repeat(STORAGE_QUOTA_BYTES / 2 - 1);
        assert!(s.set("k".into(), half.clone()));
        assert!(
            s.set("k".into(), half.clone()),
            "overwrite frees the old value"
        );
        assert!(s.set("l".into(), half.clone()));
        assert!(!s.set("m".into(), "y".repeat(10)), "full");
        assert_eq!(s.get("m"), None);
        s.remove("l");
        assert!(s.set("m".into(), "y".repeat(10)));
    }

    #[test]
    fn json_escapes_quotes_controls_and_keeps_unicode() {
        let mut s = Storage::default();
        s.set("k\"".into(), "a\\b\n\u{1}é漢".into());
        assert_eq!(
            s.changed_json().unwrap(),
            "{\"k\\\"\":\"a\\\\b\\n\\u0001é漢\"}"
        );
    }
}
