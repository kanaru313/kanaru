//! `Element.text()`: the text content of an element as lines.

use scraper::{ElementRef, Node};

/// Elements whose content is cut out of the text (code, not words).
fn is_hidden(name: &str) -> bool {
    matches!(name, "script" | "style" | "template" | "noscript")
}

/// Elements that end a line before and after their content.
fn is_block(name: &str) -> bool {
    matches!(
        name,
        "p" | "div"
            | "li"
            | "h1"
            | "h2"
            | "h3"
            | "h4"
            | "h5"
            | "h6"
            | "tr"
            | "table"
            | "section"
            | "article"
            | "blockquote"
            | "header"
            | "footer"
            | "pre"
    )
}

/// The text built so far and how many line breaks end it (counted up to 2,
/// outside `<pre>`: a third break in a row is dropped).
struct Lines {
    text: String,
    breaks: u32,
}

impl Lines {
    /// `<br>`: a line break, but never more than one blank line in a row.
    fn hard_break(&mut self) {
        if self.breaks < 2 {
            self.text.push('\n');
            self.breaks += 1;
        }
    }

    /// A block edge: ends the current line, if there is one.
    fn soft_break(&mut self) {
        if !self.text.is_empty() && !self.text.ends_with('\n') {
            self.text.push('\n');
            self.breaks = 1;
        }
    }

    fn at_line_start(&self) -> bool {
        self.text.is_empty() || self.text.ends_with('\n')
    }

    fn push_char(&mut self, ch: char) {
        self.text.push(ch);
        self.breaks = 0;
    }

    /// Preformatted text, exactly as written.
    fn push_raw(&mut self, raw: &str) {
        self.text.push_str(raw);
        self.breaks = self
            .text
            .bytes()
            .rev()
            .take_while(|b| *b == b'\n')
            .take(2)
            .count() as u32;
    }
}

/// Text of `root` and its descendants. HTML whitespace runs become one space
/// (none at the start or end of a line), `<br>` is a line break, block
/// elements start and end a line, table cells are separated by a space, and
/// more than one blank line in a row collapses to one. Inside `<pre>` the
/// text is kept as written, line breaks included. Comments, `<script>`,
/// `<style>`, `<template>` and `<noscript>` add nothing. Walks the tree with
/// a loop, so depth cannot overflow the stack.
pub fn text_of(root: ElementRef<'_>) -> String {
    let mut out = Lines {
        text: String::new(),
        breaks: 0,
    };
    // A space is owed before the next text (whitespace was seen, or a table
    // cell ended), unless that text starts a line.
    let mut pending_space = false;
    let mut hidden_until = None;
    let mut in_pre = 0u32;
    for edge in root.traverse() {
        let (node, opening) = match edge {
            ego_tree::iter::Edge::Open(n) => (n, true),
            ego_tree::iter::Edge::Close(n) => (n, false),
        };
        if let Some(id) = hidden_until {
            if !opening && node.id() == id {
                hidden_until = None;
            }
            continue;
        }
        match node.value() {
            Node::Text(text) if opening => {
                if in_pre > 0 {
                    if pending_space && !out.at_line_start() {
                        out.push_char(' ');
                    }
                    pending_space = false;
                    out.push_raw(text);
                    continue;
                }
                for ch in text.chars() {
                    if ch.is_ascii_whitespace() {
                        pending_space = true;
                        continue;
                    }
                    if pending_space && !out.at_line_start() {
                        out.push_char(' ');
                    }
                    pending_space = false;
                    out.push_char(ch);
                }
            }
            Node::Element(el) => {
                let name = el.name();
                if name == "pre" {
                    if opening {
                        in_pre += 1;
                    } else {
                        in_pre -= 1;
                    }
                }
                if opening && is_hidden(name) {
                    hidden_until = Some(node.id());
                } else if opening && name == "br" {
                    out.hard_break();
                    pending_space = false;
                } else if is_block(name) {
                    out.soft_break();
                    pending_space = false;
                } else if !opening && matches!(name, "td" | "th") {
                    pending_space = true;
                }
            }
            _ => {}
        }
    }
    out.text.trim_matches('\n').to_owned()
}

#[cfg(test)]
mod tests {
    use super::*;
    use scraper::Html;

    fn text(html: &str) -> String {
        let doc = Html::parse_document(html);
        text_of(doc.root_element())
    }

    #[test]
    fn br_and_blocks_make_lines_and_whitespace_collapses() {
        assert_eq!(text("<p>a  b\n  c<br>d</p><div>e</div>f"), "a b c\nd\ne\nf");
        assert_eq!(text("<body>one<br><br><br><br>two</body>"), "one\n\ntwo");
        assert_eq!(text("<ul><li>x</li>\n<li> y </li></ul>"), "x\ny");
    }

    #[test]
    fn script_style_and_comments_add_nothing() {
        assert_eq!(
            text("<body>a<script>var x = 1;</script><style>p{}</style><!-- c -->b</body>"),
            "ab"
        );
    }

    #[test]
    fn pre_keeps_its_line_breaks_and_noscript_is_hidden() {
        assert_eq!(
            text("<body><pre>one\n  two\nthree</pre><noscript><p>enable js</p></noscript></body>"),
            "one\n  two\nthree"
        );
        assert_eq!(text("<body>a<noscript>hidden</noscript>b</body>"), "ab");
    }

    #[test]
    fn more_blocks_end_a_line() {
        assert_eq!(
            text("<body><header>h</header><section>s</section><article>a</article><blockquote>q</blockquote><table><tr><td>x</td></tr><tr><td>y</td></tr></table><footer>f</footer></body>"),
            "h\ns\na\nq\nx\ny\nf"
        );
    }

    #[test]
    fn pre_is_a_block_keeps_blank_lines_and_gets_the_owed_space() {
        assert_eq!(
            text("<body>a <pre>b\n\n\n\nc</pre> d</body>"),
            "a\nb\n\n\n\nc\nd"
        );
        assert_eq!(text("<body><b>x</b> <pre>y</pre></body>"), "x\ny");
        assert_eq!(
            text("<body><span>x</span> <span><pre>z</pre></span></body>"),
            "x\nz"
        );
    }

    #[test]
    fn table_cells_are_separated_by_one_space_and_rows_by_a_line() {
        assert_eq!(
            text("<table><tr><td>a</td><td>b</td><th>c</th></tr><tr><td>d</td></tr></table>"),
            "a b c\nd"
        );
        assert_eq!(
            text("<table><tr><td>a <b>b</b></td><td>c</td></tr></table>"),
            "a b c"
        );
    }

    #[test]
    fn non_breaking_space_is_kept() {
        assert_eq!(text("<body>a&nbsp;b</body>"), "a\u{a0}b");
    }
}
