//! Turns ID3v2 `SYLT` frames (synchronized lyrics) into timed lines.
//!
//! lofty keeps `SYLT` as a binary frame; this parses it and picks the frame
//! worth showing.

use lofty::id3::v2::{
    Frame, Id3v2Tag, SyncTextContentType, SynchronizedTextFrame, TimestampFormat,
};

use crate::api::lyrics::SyncedLyricLine;

/// Most lines kept from one frame. Real songs have a few hundred; the rest
/// of a larger frame is dropped.
pub(crate) const MAX_SYNCED_LINES: usize = 10_000;

/// Most text bytes kept from one frame, over all its lines.
pub(crate) const MAX_SYNCED_TEXT_BYTES: usize = 1024 * 1024;

/// The timed lines of the best `SYLT` frame in `tag`, sorted by time; empty
/// when there is none. A frame typed as lyrics wins over one typed as
/// "other" (some taggers write that); every other content type (chords,
/// events, trivia) is ignored, as are frames timed in MPEG frames, which
/// need the stream's frame length to turn into milliseconds.
pub(crate) fn synced_lines(tag: &Id3v2Tag) -> Vec<SyncedLyricLine> {
    let mut other: Option<SynchronizedTextFrame<'static>> = None;
    for frame in tag {
        let Frame::Binary(binary) = frame else {
            continue;
        };
        if frame.id_str() != "SYLT" {
            continue;
        }
        let Ok(parsed) =
            SynchronizedTextFrame::parse(&with_valid_language(&binary.data), frame.flags())
        else {
            continue;
        };
        if parsed.timestamp_format != TimestampFormat::MS || parsed.content.is_empty() {
            continue;
        }
        match parsed.content_type {
            SyncTextContentType::Lyrics => return lines_of(parsed.content),
            SyncTextContentType::Other if other.is_none() => other = Some(parsed),
            _ => {}
        }
    }
    other
        .map(|frame| lines_of(frame.content))
        .unwrap_or_default()
}

/// The frame body with its language code made valid. lofty refuses a code
/// that is not three ASCII letters, and many taggers write `\0\0\0` or
/// `XXX`-like junk there; the language is not used.
fn with_valid_language(data: &[u8]) -> std::borrow::Cow<'_, [u8]> {
    match data.get(1..4) {
        Some(code) if !code.iter().all(u8::is_ascii_alphabetic) => {
            let mut fixed = data.to_vec();
            fixed[1..4].copy_from_slice(b"xxx");
            std::borrow::Cow::Owned(fixed)
        }
        _ => std::borrow::Cow::Borrowed(data),
    }
}

/// `content` as lines, sorted by time keeping the frame's order for equal
/// times, capped by [`MAX_SYNCED_LINES`] and [`MAX_SYNCED_TEXT_BYTES`].
///
/// Two layouts exist: one entry per line, or one entry per syllable where an
/// entry starting with a line break opens a new line (karaoke). In the
/// second, the syllables of a line are joined and the line takes the time of
/// its first syllable. Line breaks around each line are trimmed.
pub(crate) fn lines_of(content: Vec<(u32, String)>) -> Vec<SyncedLyricLine> {
    let starts_line = |text: &str| text.starts_with(['\r', '\n']);
    let syllables = content.iter().skip(1).any(|(_, text)| starts_line(text))
        && content.iter().skip(1).any(|(_, text)| !starts_line(text));
    let mut grouped: Vec<(u32, String)> = Vec::new();
    for (time_ms, text) in content {
        match grouped.last_mut() {
            Some((_, line)) if syllables && !starts_line(&text) => line.push_str(&text),
            _ => grouped.push((time_ms, text)),
        }
        if grouped.len() > MAX_SYNCED_LINES {
            grouped.pop();
            break;
        }
    }
    let mut bytes = 0usize;
    let mut lines = Vec::with_capacity(grouped.len());
    for (time_ms, text) in grouped {
        let text = text.trim_matches(['\r', '\n']).to_owned();
        bytes += text.len();
        if bytes > MAX_SYNCED_TEXT_BYTES {
            break;
        }
        lines.push(SyncedLyricLine { time_ms, text });
    }
    lines.sort_by_key(|line| line.time_ms);
    lines
}

#[cfg(test)]
mod tests {
    use super::*;

    fn line(time_ms: u32, text: &str) -> SyncedLyricLine {
        SyncedLyricLine {
            time_ms,
            text: text.to_owned(),
        }
    }

    #[test]
    fn trims_line_breaks_and_sorts_stably() {
        let lines = lines_of(vec![
            (2000, "\nsecond".to_owned()),
            (1000, "first\r\n".to_owned()),
            (2000, "  same time  ".to_owned()),
        ]);
        assert_eq!(
            lines,
            vec![
                line(1000, "first"),
                line(2000, "second"),
                line(2000, "  same time  "),
            ]
        );
    }

    #[test]
    fn joins_syllables_into_lines() {
        let lines = lines_of(vec![
            (100, "Hel".to_owned()),
            (200, "lo ".to_owned()),
            (300, "world".to_owned()),
            (900, "\nSe".to_owned()),
            (1000, "cond".to_owned()),
        ]);
        assert_eq!(lines, vec![line(100, "Hello world"), line(900, "Second")]);
    }

    #[test]
    fn every_entry_led_by_a_break_is_a_line() {
        let lines = lines_of(vec![
            (100, "One".to_owned()),
            (200, "\nTwo".to_owned()),
            (300, "\nThree".to_owned()),
        ]);
        assert_eq!(
            lines,
            vec![line(100, "One"), line(200, "Two"), line(300, "Three")]
        );
    }

    #[test]
    fn fixes_a_junk_language_code() {
        let data = b"\x03\0\0\0\x02\x01rest";
        assert_eq!(&with_valid_language(data)[1..4], b"xxx");
        let good = b"\x03eng\x02\x01rest";
        assert!(matches!(
            with_valid_language(good),
            std::borrow::Cow::Borrowed(_)
        ));
    }

    #[test]
    fn caps_the_line_count() {
        let content = (0..MAX_SYNCED_LINES as u32 + 5)
            .map(|i| (i, "x".to_owned()))
            .collect();
        assert_eq!(lines_of(content).len(), MAX_SYNCED_LINES);
    }

    #[test]
    fn caps_the_text_size() {
        let big = "y".repeat(MAX_SYNCED_TEXT_BYTES / 2 + 1);
        let lines = lines_of(vec![(0, big.clone()), (1, big.clone()), (2, big)]);
        assert_eq!(lines.len(), 1);
    }
}
