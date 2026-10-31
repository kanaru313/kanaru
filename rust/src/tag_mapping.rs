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

/// Longest stored language tag, in bytes.
const MAX_LANGUAGE_BYTES: usize = 128;

/// Longest accepted raw release date, in bytes. A date is never longer, so a
/// longer value is junk and is dropped rather than cut.
const MAX_RELEASE_DATE_BYTES: usize = 64;

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
    out.release_date = release_date(tag);
    out.genre = capped(non_empty(tag.genre()), MAX_TEXT_BYTES);
    out.composer = capped(
        non_empty(tag.get_string(ItemKey::Composer).map(Into::into)),
        MAX_TEXT_BYTES,
    );
    out.comment = capped(non_empty(tag.comment()), MAX_COMMENT_BYTES);
    out.language = languages(tag);
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

/// The raw release date: the first usable of recording date, release date,
/// year and original release date. A value that is empty after cleaning or
/// longer than [`MAX_RELEASE_DATE_BYTES`] is skipped, so the next key is tried.
/// Control characters are dropped. `year` reads recording date, then year, so
/// the two agree on the date's year only when a recording date is present;
/// without one the release date may come from `ReleaseDate` while `year`
/// comes from `Year`.
fn release_date(tag: &Tag) -> Option<String> {
    [
        ItemKey::RecordingDate,
        ItemKey::ReleaseDate,
        ItemKey::Year,
        ItemKey::OriginalReleaseDate,
    ]
    .into_iter()
    .filter_map(|key| tag.get_string(key))
    .map(|raw| {
        raw.chars()
            .filter(|c| !c.is_control())
            .collect::<String>()
            .trim()
            .to_owned()
    })
    .find(|v| !v.is_empty() && v.len() <= MAX_RELEASE_DATE_BYTES)
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

/// Every language value joined with [`ARTIST_SEPARATOR`] (ID3v2.4 null-separated
/// `TLAN`, repeated Vorbis `LANGUAGE`). Cut to [`MAX_LANGUAGE_BYTES`] and
/// trimmed again, so a cut after a separator leaves no dangling `;` or space.
fn languages(tag: &Tag) -> Option<String> {
    let all: Vec<&str> = tag
        .get_strings(ItemKey::Language)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .collect();
    if all.is_empty() {
        return None;
    }
    let joined = all.join(ARTIST_SEPARATOR);
    let cut = cut(&joined, MAX_LANGUAGE_BYTES)
        .trim_end_matches(|c: char| c.is_whitespace() || c == ';');
    (!cut.is_empty()).then(|| cut.to_owned())
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

    fn release_of(items: &[(ItemKey, &str)]) -> Option<String> {
        let mut tag = Tag::new(TagType::VorbisComments);
        for (key, value) in items {
            tag.insert_text(*key, (*value).to_owned());
        }
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        out.release_date
    }

    #[test]
    fn release_date_follows_key_order() {
        let all = [
            (ItemKey::OriginalReleaseDate, "1970"),
            (ItemKey::Year, "1985"),
            (ItemKey::ReleaseDate, "2020-01-01"),
            (ItemKey::RecordingDate, " 2019-07-15 "),
        ];
        assert_eq!(release_of(&all).as_deref(), Some("2019-07-15"));
        assert_eq!(release_of(&all[..3]).as_deref(), Some("2020-01-01"));
        assert_eq!(release_of(&all[..2]).as_deref(), Some("1985"));
        assert_eq!(release_of(&all[..1]).as_deref(), Some("1970"));
        assert_eq!(release_of(&[]), None);
    }

    #[test]
    fn oversized_recording_date_falls_back_to_the_next_key() {
        let long = "9".repeat(65);
        assert_eq!(
            release_of(&[
                (ItemKey::RecordingDate, &long),
                (ItemKey::ReleaseDate, "2020-01-01"),
            ])
            .as_deref(),
            Some("2020-01-01")
        );
        assert_eq!(
            release_of(&[(ItemKey::RecordingDate, &long), (ItemKey::Year, "1985")]).as_deref(),
            Some("1985")
        );
    }

    #[test]
    fn release_date_drops_control_chars_blank_and_long_values() {
        assert_eq!(
            release_of(&[(ItemKey::RecordingDate, "20\u{0}19\n")]).as_deref(),
            Some("2019")
        );
        assert_eq!(release_of(&[(ItemKey::RecordingDate, " \t ")]), None);
        assert_eq!(
            release_of(&[(ItemKey::RecordingDate, &"9".repeat(65))]),
            None
        );
        assert!(release_of(&[(ItemKey::RecordingDate, &"9".repeat(64))]).is_some());
    }

    #[test]
    fn language_is_read_from_vorbis_and_id3() {
        for tag_type in [TagType::VorbisComments, TagType::Id3v2] {
            let mut tag = Tag::new(tag_type);
            tag.insert_text(ItemKey::Language, " vie ".into());
            let mut out = TrackTags::default();
            apply_tag(&mut out, &tag);
            assert_eq!(out.language.as_deref(), Some("vie"));
        }
    }

    #[test]
    fn blank_or_missing_language_is_none() {
        let mut tag = Tag::new(TagType::VorbisComments);
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        assert_eq!(out.language, None);
        tag.insert_text(ItemKey::Language, "  \t ".into());
        apply_tag(&mut out, &tag);
        assert_eq!(out.language, None);
    }

    #[test]
    fn long_multibyte_language_is_cut_at_a_character_boundary() {
        let mut tag = Tag::new(TagType::VorbisComments);
        // 200 bytes of 3-byte characters: 128 is not a multiple of 3.
        tag.insert_text(ItemKey::Language, "語".repeat(67));
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        let language = out.language.unwrap();
        assert_eq!(language.len(), 126);
        assert!(language.chars().all(|c| c == '語'));
    }

    #[test]
    fn several_language_values_are_joined() {
        let mut tag = Tag::new(TagType::VorbisComments);
        for code in ["eng", " jpn ", ""] {
            tag.push(lofty::tag::TagItem::new(
                ItemKey::Language,
                lofty::tag::ItemValue::Text(code.into()),
            ));
        }
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        assert_eq!(out.language.as_deref(), Some("eng; jpn"));
    }

    #[test]
    fn language_cut_after_a_separator_has_no_trailing_separator() {
        let mut tag = Tag::new(TagType::VorbisComments);
        // 126 + "; " puts the cut right after the separator at byte 128.
        for value in ["a".repeat(126), "bbb".to_owned()] {
            tag.push(lofty::tag::TagItem::new(
                ItemKey::Language,
                lofty::tag::ItemValue::Text(value),
            ));
        }
        let mut out = TrackTags::default();
        apply_tag(&mut out, &tag);
        assert_eq!(out.language.unwrap(), "a".repeat(126));
    }
}
