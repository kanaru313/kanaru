//! Pure mapping from lofty tags and properties to [`TrackTags`]. No file I/O,
//! so it is tested with in-memory tags.

use lofty::prelude::*;
use lofty::properties::FileProperties;
use lofty::tag::{ItemKey, Tag};

use crate::api::tags::TrackTags;

/// Longest stored title, artist, album, album artist, genre and composer, in
/// bytes. A hostile tag cannot make a database row or a list tile huge.
const MAX_TEXT_BYTES: usize = 1024;

/// Longest stored comment, in bytes.
const MAX_COMMENT_BYTES: usize = 4096;

/// Most artist values joined into the artist field.
const MAX_ARTISTS: usize = 32;

/// Separator between artists when a track lists more than one.
const ARTIST_SEPARATOR: &str = "; ";

/// First four ASCII digits of [`raw`] as a year: `"2019-05-01"` gives 2019.
/// `None` when the value does not start with four digits.
pub fn parse_year(raw: &str) -> Option<u32> {
    let head = raw.trim().get(..4)?;
    if head.bytes().all(|b| b.is_ascii_digit()) {
        head.parse().ok()
    } else {
        None
    }
}

/// Copies the textual and numeric fields of [`tag`] into [`out`].
pub fn apply_tag(out: &mut TrackTags, tag: &Tag) {
    out.title = capped(non_empty(tag.title()), MAX_TEXT_BYTES);
    out.artist = capped(artists(tag), MAX_TEXT_BYTES);
    out.album = capped(non_empty(tag.album()), MAX_TEXT_BYTES);
    out.album_artist = capped(
        non_empty(tag.get_string(ItemKey::AlbumArtist).map(Into::into)),
        MAX_TEXT_BYTES,
    );
    out.track_no = tag.track();
    out.track_total = tag.track_total();
    out.disc_no = tag.disk();
    out.disc_total = tag.disk_total();
    out.year = tag
        .get_string(ItemKey::RecordingDate)
        .or_else(|| tag.get_string(ItemKey::Year))
        .and_then(parse_year);
    out.genre = capped(non_empty(tag.genre()), MAX_TEXT_BYTES);
    out.composer = capped(
        non_empty(tag.get_string(ItemKey::Composer).map(Into::into)),
        MAX_TEXT_BYTES,
    );
    out.comment = capped(non_empty(tag.comment()), MAX_COMMENT_BYTES);
}

/// Copies the audio properties into [`out`]. Zero means "unknown" in several
/// formats, so it maps to `None`.
pub fn apply_properties(out: &mut TrackTags, props: &FileProperties) {
    let duration_ms = props.duration().as_millis();
    out.duration_ms = i64::try_from(duration_ms).ok().filter(|ms| *ms > 0);
    out.bitrate = props.overall_bitrate().filter(|v| *v > 0);
    out.sample_rate = props.sample_rate().filter(|v| *v > 0);
    out.bit_depth = props.bit_depth().filter(|v| *v > 0);
    out.channels = props.channels().filter(|v| *v > 0);
}

/// All track artists joined with [`ARTIST_SEPARATOR`]. Prefers the explicit
/// multi-value `TrackArtists` key; otherwise collects every `TrackArtist`
/// value (repeated Vorbis `ARTIST=` fields, null-separated ID3v2.4 `TPE1`).
fn artists(tag: &Tag) -> Option<String> {
    let collect = |key: ItemKey| -> Vec<&str> {
        tag.get_strings(key)
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(|s| cut(s, MAX_TEXT_BYTES))
            .take(MAX_ARTISTS)
            .collect()
    };
    let mut all = collect(ItemKey::TrackArtists);
    if all.is_empty() {
        all = collect(ItemKey::TrackArtist);
    }
    if all.is_empty() {
        non_empty(tag.artist())
    } else {
        Some(all.join(ARTIST_SEPARATOR))
    }
}

/// [`value`] cut to at most [`max_bytes`] bytes at a character boundary, so
/// multi-byte text is never split.
fn capped(value: Option<String>, max_bytes: usize) -> Option<String> {
    value.map(|mut text| {
        text.truncate(cut(&text, max_bytes).len());
        text
    })
}

/// The longest prefix of [`text`] of at most [`max_bytes`] bytes that ends at
/// a character boundary.
fn cut(text: &str, max_bytes: usize) -> &str {
    let mut end = max_bytes.min(text.len());
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    &text[..end]
}

/// Trims [`value`] and drops it when nothing is left.
fn non_empty(value: Option<std::borrow::Cow<'_, str>>) -> Option<String> {
    value.map(|v| v.trim().to_owned()).filter(|v| !v.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;
    use lofty::tag::TagType;

    #[test]
    fn year_takes_first_four_digits() {
        assert_eq!(parse_year("2019-05-01"), Some(2019));
        assert_eq!(parse_year(" 1999 "), Some(1999));
        assert_eq!(parse_year("2001"), Some(2001));
    }

    #[test]
    fn year_rejects_non_numeric_and_short_values() {
        assert_eq!(parse_year(""), None);
        assert_eq!(parse_year("May 2019"), None);
        assert_eq!(parse_year("99"), None);
        // Multi-byte text must not panic on a char boundary.
        assert_eq!(parse_year("年年年年"), None);
    }

    #[test]
    fn multiple_artists_are_joined() {
        let mut tag = Tag::new(TagType::VorbisComments);
        tag.push(lofty::tag::TagItem::new(
            ItemKey::TrackArtists,
            lofty::tag::ItemValue::Text("A".into()),
        ));
        tag.push(lofty::tag::TagItem::new(
            ItemKey::TrackArtists,
            lofty::tag::ItemValue::Text("B".into()),
        ));
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        assert_eq!(out.artist.as_deref(), Some("A; B"));
    }

    #[test]
    fn repeated_artist_fields_are_joined() {
        let mut tag = Tag::new(TagType::VorbisComments);
        for name in ["A", " B ", ""] {
            tag.push(lofty::tag::TagItem::new(
                ItemKey::TrackArtist,
                lofty::tag::ItemValue::Text(name.into()),
            ));
        }
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        assert_eq!(out.artist.as_deref(), Some("A; B"));
    }

    #[test]
    fn single_artist_falls_back_to_artist_accessor() {
        let mut tag = Tag::new(TagType::Id3v2);
        tag.set_artist("Solo".into());
        tag.set_title("  Song ".into());
        tag.set_album(String::new());
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        assert_eq!(out.artist.as_deref(), Some("Solo"));
        assert_eq!(out.title.as_deref(), Some("Song"));
        assert_eq!(out.album, None);
    }

    #[test]
    fn long_multibyte_title_is_cut_at_a_character_boundary() {
        let mut tag = Tag::new(TagType::Id3v2);
        // 3-byte characters: 1024 is not a multiple of 3, so a byte cut
        // would land inside one.
        tag.set_title("あ".repeat(700));
        tag.set_comment("é".repeat(5000));
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        let title = out.title.unwrap();
        assert_eq!(title.len(), 1023);
        assert!(title.chars().all(|c| c == 'あ'));
        assert_eq!(out.comment.unwrap().len(), 4096);
    }

    #[test]
    fn thousands_of_artists_are_limited_before_joining() {
        let mut tag = Tag::new(TagType::VorbisComments);
        for i in 0..10_000 {
            tag.push(lofty::tag::TagItem::new(
                ItemKey::TrackArtists,
                lofty::tag::ItemValue::Text(format!("Artist {i}")),
            ));
        }
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        let artist = out.artist.unwrap();
        assert_eq!(artist.split("; ").count(), 32);
        assert!(artist.len() <= 1024);
    }

    #[test]
    fn each_artist_value_is_capped_before_joining() {
        let mut tag = Tag::new(TagType::VorbisComments);
        for _ in 0..32 {
            tag.push(lofty::tag::TagItem::new(
                ItemKey::TrackArtists,
                lofty::tag::ItemValue::Text("é".repeat(100_000)),
            ));
        }
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        // 32 values of at most 1 KB, cut again to 1 KB after joining.
        assert_eq!(out.artist.unwrap().len(), 1024);
    }

    #[test]
    fn year_prefers_recording_date() {
        let mut tag = Tag::new(TagType::Id3v2);
        tag.insert_text(ItemKey::RecordingDate, "2019-05-01".into());
        tag.insert_text(ItemKey::Year, "1985".into());
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        assert_eq!(out.year, Some(2019));
    }
}
