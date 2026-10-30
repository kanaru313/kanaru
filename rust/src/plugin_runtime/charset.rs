//! Decoding of response bodies for `response.text(charset?)`.

use encoding_rs::{Encoding, UTF_8};

/// The `charset` parameter of a `Content-Type` value, if any.
fn content_type_charset(content_type: &str) -> Option<&str> {
    content_type.split(';').skip(1).find_map(|param| {
        let (name, value) = param.split_once('=')?;
        name.trim()
            .eq_ignore_ascii_case("charset")
            .then(|| value.trim().trim_matches('"').trim())
    })
}

/// Decodes `bytes`: by `explicit` label when given (an unknown one gives
/// `None`), else by the `Content-Type` charset (an unknown one is ignored),
/// else UTF-8. Malformed input becomes U+FFFD; a leading BOM of the chosen
/// encoding is dropped.
pub fn decode(bytes: &[u8], explicit: Option<&str>, content_type: Option<&str>) -> Option<String> {
    let encoding: &'static Encoding = match explicit {
        Some(label) => Encoding::for_label(label.trim().as_bytes())?,
        None => content_type
            .and_then(content_type_charset)
            .and_then(|label| Encoding::for_label(label.as_bytes()))
            .unwrap_or(UTF_8),
    };
    Some(encoding.decode_with_bom_removal(bytes).0.into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn explicit_label_wins_over_the_header() {
        let gbk = encoding_rs::GBK.encode("歌词").0.into_owned();
        assert_eq!(
            decode(&gbk, Some("GBK"), Some("text/plain; charset=utf-8")).unwrap(),
            "歌词"
        );
    }

    #[test]
    fn header_charset_then_utf8_lossy() {
        let big5 = encoding_rs::BIG5.encode("歌詞").0.into_owned();
        assert_eq!(
            decode(&big5, None, Some("text/html; Charset=\"Big5\"")).unwrap(),
            "歌詞"
        );
        assert_eq!(decode(b"a\xffb", None, None).unwrap(), "a\u{fffd}b");
        assert_eq!(
            decode("é".as_bytes(), None, Some("text/plain; charset=nope")).unwrap(),
            "é"
        );
        assert_eq!(decode(b"\xef\xbb\xbfhi", None, None).unwrap(), "hi");
    }

    #[test]
    fn unknown_explicit_label_is_an_error() {
        assert_eq!(decode(b"x", Some("klingon"), None), None);
    }
}
