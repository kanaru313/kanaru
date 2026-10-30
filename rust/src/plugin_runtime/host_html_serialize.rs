//! `Element.html()` / `outerHtml()` with a size cap.
//!
//! html5ever clones formatting elements while it repairs misnested markup, and
//! the clones share one attribute buffer; the serializer writes every clone's
//! attributes out in full. A 3 MB attribute value and 27 000 clones would ask
//! for gigabytes. The output therefore goes through a writer that charges the
//! job's byte budget as it writes and refuses past a cap.

use std::io::{self, Write};

use html5ever::serialize::{serialize, SerializeOpts, TraversalScope};
use scraper::ElementRef;

use super::host_budget::ByteBudget;

/// Largest serialized HTML one call returns, in bytes.
pub const MAX_SERIALIZED_BYTES: usize = 4 * 1024 * 1024;

/// Why a serialization was refused.
#[derive(Debug, PartialEq, Eq)]
pub enum SerializeStop {
    /// The text passed [`MAX_SERIALIZED_BYTES`].
    TooLarge,
    /// The shared byte budget refused a charge (it is marked as hit).
    OverBudget,
}

/// Collects output, charging `budget` for every byte kept.
struct LimitedWriter<'b> {
    buf: Vec<u8>,
    budget: &'b ByteBudget,
    cap: usize,
    why: Option<SerializeStop>,
}

impl Write for LimitedWriter<'_> {
    fn write(&mut self, data: &[u8]) -> io::Result<usize> {
        if self.buf.len().saturating_add(data.len()) > self.cap {
            self.why = Some(SerializeStop::TooLarge);
            return Err(io::Error::other("serialized HTML too large"));
        }
        if !self.budget.try_charge(data.len()) {
            self.why = Some(SerializeStop::OverBudget);
            return Err(io::Error::other("byte budget exhausted"));
        }
        // Double as usual, but never past the output cap: the buffer is at
        // most the cap even when only part of it is in use.
        let needed = self.buf.len() + data.len();
        if needed > self.buf.capacity() {
            let target = (self.buf.capacity() * 2)
                .max(needed)
                .max(64)
                .min(self.cap.max(needed));
            self.buf.reserve_exact(target - self.buf.len());
        }
        self.buf.extend_from_slice(data);
        Ok(data.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

/// The HTML of `el` (`outer`: with the element itself) or the refusal. The
/// bytes are charged to `budget` while they are written and given back before
/// returning: the caller turns the text into a JS string right away.
pub fn serialize_limited(
    el: &ElementRef<'_>,
    outer: bool,
    budget: &ByteBudget,
    cap: usize,
) -> Result<String, SerializeStop> {
    let mut writer = LimitedWriter {
        buf: Vec::new(),
        budget,
        cap,
        why: None,
    };
    let opts = SerializeOpts {
        scripting_enabled: false,
        traversal_scope: if outer {
            TraversalScope::IncludeNode
        } else {
            TraversalScope::ChildrenOnly(None)
        },
        create_missing_parent: false,
    };
    let written = serialize(&mut writer, el, opts);
    let charged = writer.buf.len();
    budget.release(charged);
    if let Some(why) = writer.why {
        return Err(why);
    }
    // Only the writer produces errors here, and it records why.
    written.map_err(|_| SerializeStop::TooLarge)?;
    String::from_utf8(writer.buf).map_err(|_| SerializeStop::TooLarge)
}

#[cfg(test)]
mod tests {
    use super::*;
    use scraper::Html;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::Arc;

    fn budget(limit: usize) -> (ByteBudget, Arc<AtomicBool>) {
        let hit = Arc::new(AtomicBool::new(false));
        (ByteBudget::new(limit, hit.clone()), hit)
    }

    #[test]
    fn serializes_inner_and_outer_and_gives_the_charge_back() {
        let doc = Html::parse_document("<body><div id=a>x<b>y</b></div></body>");
        let sel = scraper::Selector::parse("#a").unwrap();
        let div = doc.select(&sel).next().unwrap();
        let (b, hit) = budget(1000);
        assert_eq!(
            serialize_limited(&div, true, &b, 1000).unwrap(),
            "<div id=\"a\">x<b>y</b></div>"
        );
        assert_eq!(
            serialize_limited(&div, false, &b, 1000).unwrap(),
            "x<b>y</b>"
        );
        assert!(b.try_charge(1000), "everything was released");
        assert!(!hit.load(Ordering::SeqCst));
    }

    #[test]
    fn the_cap_and_the_budget_both_refuse() {
        let doc = Html::parse_document(&format!("<body><p>{}</p></body>", "x".repeat(500)));
        let root = doc.root_element();
        let (b, hit) = budget(10_000);
        assert_eq!(
            serialize_limited(&root, true, &b, 100),
            Err(SerializeStop::TooLarge)
        );
        assert!(
            !hit.load(Ordering::SeqCst),
            "the cap alone does not mark the budget"
        );
        let (b, hit) = budget(100);
        assert_eq!(
            serialize_limited(&root, true, &b, 10_000),
            Err(SerializeStop::OverBudget)
        );
        assert!(hit.load(Ordering::SeqCst));
    }
}
