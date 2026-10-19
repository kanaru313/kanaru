//! Pure mapping from lofty tags and properties to [`TrackTags`]. No file I/O,
//! so it is tested with in-memory tags.

use lofty::prelude::*;
use lofty::properties::FileProperties;
use lofty::tag::{ItemKey, Tag};

use crate::api::tags::TrackTags;

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
    out.title = non_empty(tag.title());
    out.artist = artists(tag);
    out.album = non_empty(tag.album());
    out.album_artist = non_empty(tag.get_string(ItemKey::AlbumArtist).map(Into::into));
    out.track_no = tag.track();
    out.track_total = tag.track_total();
    out.disc_no = tag.disk();
    out.disc_total = tag.disk_total();
    out.year = tag
        .get_string(ItemKey::RecordingDate)
        .or_else(|| tag.get_string(ItemKey::Year))
        .and_then(parse_year);
    out.genre = non_empty(tag.genre());
    out.composer = non_empty(tag.get_string(ItemKey::Composer).map(Into::into));
    out.comment = non_empty(tag.comment());
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

/// All track artists joined with [`ARTIST_SEPARATOR`]; falls back to the
/// single `artist()` value for formats without a multi-value artist key.
fn artists(tag: &Tag) -> Option<String> {
    let all: Vec<&str> = tag
        .get_strings(ItemKey::TrackArtists)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .collect();
    if all.is_empty() {
        non_empty(tag.artist())
    } else {
        Some(all.join(ARTIST_SEPARATOR))
    }
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
    fn year_prefers_recording_date() {
        let mut tag = Tag::new(TagType::Id3v2);
        tag.insert_text(ItemKey::RecordingDate, "2019-05-01".into());
        tag.insert_text(ItemKey::Year, "1985".into());
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        assert_eq!(out.year, Some(2019));
    }
}
