//! Reads the few JPEG header facts the thumbnail code needs, and strips
//! metadata segments, by walking the marker list up to the first scan.
//! Every read is bounds-checked: hostile bytes give `None`, never a panic.

/// Header facts of a JPEG, from its markers before the first scan.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JpegHeader {
    pub width: u16,
    pub height: u16,
    /// Progressive Huffman (SOF2); otherwise baseline or extended (SOF0/1).
    pub progressive: bool,
    /// `(horizontal, vertical)` sampling factors, one entry per component
    /// (1 gray, 3 YCbCr or RGB, 4 CMYK or YCCK).
    pub sampling: Vec<(u8, u8)>,
    /// The transform byte of an Adobe APP14 segment: 0 none (RGB or CMYK),
    /// 1 YCbCr, 2 YCCK. `None` without such a segment.
    pub adobe_transform: Option<u8>,
    /// EXIF orientation (tag 0x0112); 1 when absent or unreadable.
    pub orientation: u16,
}

const SOI: u8 = 0xD8;
const EOI: u8 = 0xD9;
const SOS: u8 = 0xDA;
const APP14: u8 = 0xEE;
const COM: u8 = 0xFE;

/// The header of `bytes`, or `None` when it is not a JPEG this code can
/// describe: no SOI, a truncated or malformed segment, no frame header
/// before the first scan, more than one frame header, or a lossless,
/// arithmetic-coded or hierarchical frame.
pub fn parse(bytes: &[u8]) -> Option<JpegHeader> {
    let mut frame = None;
    let mut adobe_transform = None;
    let mut orientation = 1;
    for segment in segments(bytes)? {
        let segment = segment?;
        match segment.marker {
            0xC0..=0xC2 => {
                if frame.is_some() {
                    return None;
                }
                frame = Some(parse_frame(segment.marker, segment.payload)?);
            }
            // Lossless, hierarchical (differential) and arithmetic frames.
            0xC3 | 0xC5..=0xC7 | 0xC9..=0xCB | 0xCD..=0xCF => return None,
            0xE1 if segment.payload.starts_with(b"Exif\0\0") => {
                orientation = exif_orientation(segment.payload.get(6..)?).unwrap_or(1);
            }
            APP14 if segment.payload.starts_with(b"Adobe") => {
                adobe_transform = segment.payload.get(11).copied();
            }
            _ => {}
        }
    }
    let (width, height, progressive, sampling) = frame?;
    Some(JpegHeader {
        width,
        height,
        progressive,
        sampling,
        adobe_transform,
        orientation,
    })
}

/// `bytes` without its metadata segments (APP1–APP13, APP15, comments) and
/// without fill bytes between segments. The JFIF (APP0) and Adobe (APP14)
/// segments stay, since they say how to read the colours; everything from
/// the first scan on is copied as is. `None` when the marker list is
/// malformed (see [`parse`]).
pub fn strip_metadata(bytes: &[u8]) -> Option<Vec<u8>> {
    let mut out = Vec::with_capacity(bytes.len());
    out.extend_from_slice(&[0xFF, SOI]);
    for segment in segments(bytes)? {
        let segment = segment?;
        let metadata = matches!(segment.marker, 0xE1..=0xED | 0xEF | COM);
        if !metadata {
            out.extend_from_slice(bytes.get(segment.start..segment.end)?);
        }
        if segment.marker == SOS {
            out.extend_from_slice(bytes.get(segment.end..)?);
        }
    }
    Some(out)
}

/// Whether `bytes` ends right after its first scan: the entropy-coded data
/// that follows the first SOS runs, past byte stuffing (`FF 00`), restart
/// markers and fill bytes, into an EOI that is the last two bytes. `false`
/// when anything else comes first (a second scan, tables between scans,
/// data after the image) or the marker list is malformed.
pub fn ends_with_first_scan(bytes: &[u8]) -> bool {
    let Some(data_start) = first_scan_data(bytes) else {
        return false;
    };
    let mut at = data_start;
    while let Some(&byte) = bytes.get(at) {
        if byte != 0xFF {
            at += 1;
            continue;
        }
        let Some(&next) = bytes.get(at + 1) else {
            return false;
        };
        match next {
            // Fill byte: the marker byte comes later.
            0xFF => at += 1,
            // Byte stuffing and restart markers belong to the scan.
            0x00 | 0xD0..=0xD7 => at += 2,
            marker => return marker == EOI && at + 2 == bytes.len(),
        }
    }
    false
}

/// Where the entropy-coded data of the first scan starts.
fn first_scan_data(bytes: &[u8]) -> Option<usize> {
    for segment in segments(bytes)? {
        let segment = segment?;
        if segment.marker == SOS {
            return Some(segment.end);
        }
    }
    None
}

/// One marker segment: `bytes[start..end]` is the marker and its payload.
struct Segment<'a> {
    marker: u8,
    payload: &'a [u8],
    start: usize,
    end: usize,
}

/// The segments of `bytes` after SOI, up to and including the first SOS
/// (whose `end` is where the entropy-coded data starts). Yields `None` for a
/// malformed segment and stops after it. `None` when `bytes` has no SOI.
fn segments(bytes: &[u8]) -> Option<impl Iterator<Item = Option<Segment<'_>>>> {
    if bytes.get(..2)? != [0xFF, SOI] {
        return None;
    }
    let mut at = 2usize;
    let mut done = false;
    Some(std::iter::from_fn(move || {
        if done {
            return None;
        }
        let segment = next_segment(bytes, &mut at);
        done = segment.as_ref().is_none_or(|s| s.marker == SOS);
        Some(segment)
    }))
}

fn next_segment<'a>(bytes: &'a [u8], at: &mut usize) -> Option<Segment<'a>> {
    loop {
        if *bytes.get(*at)? != 0xFF {
            return None;
        }
        // Fill bytes: any number of 0xFF before the marker byte.
        let mut marker_at = at.checked_add(1)?;
        while *bytes.get(marker_at)? == 0xFF {
            marker_at = marker_at.checked_add(1)?;
        }
        let marker = *bytes.get(marker_at)?;
        let start = marker_at - 1;
        let after_marker = marker_at.checked_add(1)?;
        match marker {
            // A stray SOI or a marker without payload: skip it.
            SOI | 0x01 | 0xD0..=0xD7 => {
                *at = after_marker;
                continue;
            }
            // An image ending before its first scan has nothing to show.
            EOI | 0x00 => return None,
            _ => {}
        }
        let length_bytes = bytes.get(after_marker..after_marker.checked_add(2)?)?;
        let length = usize::from(u16::from_be_bytes([length_bytes[0], length_bytes[1]]));
        if length < 2 {
            return None;
        }
        let end = after_marker.checked_add(length)?;
        let payload = bytes.get(after_marker + 2..end)?;
        *at = end;
        return Some(Segment {
            marker,
            payload,
            start,
            end,
        });
    }
}

/// `(width, height, progressive, sampling factors)` from a SOF0–2 payload.
type Frame = (u16, u16, bool, Vec<(u8, u8)>);

fn parse_frame(marker: u8, payload: &[u8]) -> Option<Frame> {
    let height = u16::from_be_bytes([*payload.get(1)?, *payload.get(2)?]);
    let width = u16::from_be_bytes([*payload.get(3)?, *payload.get(4)?]);
    let count = usize::from(*payload.get(5)?);
    if width == 0 || height == 0 || !matches!(count, 1 | 3 | 4) {
        return None;
    }
    let components = payload.get(6..6 + 3 * count)?;
    let mut sampling = Vec::with_capacity(count);
    for component in components.chunks_exact(3) {
        let (h, v) = (component[1] >> 4, component[1] & 0x0F);
        if !(1..=4).contains(&h) || !(1..=4).contains(&v) {
            return None;
        }
        sampling.push((h, v));
    }
    Some((width, height, marker == 0xC2, sampling))
}

/// Tag 0x0112 of the first IFD of a TIFF block (the EXIF payload after
/// `Exif\0\0`).
fn exif_orientation(tiff: &[u8]) -> Option<u16> {
    let little = match tiff.get(..2)? {
        b"II" => true,
        b"MM" => false,
        _ => return None,
    };
    let u16_at = |at: usize| -> Option<u16> {
        let b = tiff.get(at..at.checked_add(2)?)?;
        Some(if little {
            u16::from_le_bytes([b[0], b[1]])
        } else {
            u16::from_be_bytes([b[0], b[1]])
        })
    };
    let u32_at = |at: usize| -> Option<usize> {
        let b = tiff.get(at..at.checked_add(4)?)?;
        let value = if little {
            u32::from_le_bytes([b[0], b[1], b[2], b[3]])
        } else {
            u32::from_be_bytes([b[0], b[1], b[2], b[3]])
        };
        usize::try_from(value).ok()
    };
    let ifd = u32_at(4)?;
    let entries = usize::from(u16_at(ifd)?);
    for index in 0..entries {
        let entry = ifd.checked_add(2)?.checked_add(index.checked_mul(12)?)?;
        if u16_at(entry)? == 0x0112 {
            return u16_at(entry.checked_add(8)?);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    /// SOI, an APP segment, a SOF0 for `w`×`h` with 3 components, SOS, data.
    fn minimal(w: u16, h: u16) -> Vec<u8> {
        let mut b = vec![0xFF, SOI];
        b.extend_from_slice(&[0xFF, 0xE1, 0x00, 0x04, 0xAA, 0xBB]);
        b.extend_from_slice(&[0xFF, 0xC0, 0x00, 0x11, 8]);
        b.extend_from_slice(&h.to_be_bytes());
        b.extend_from_slice(&w.to_be_bytes());
        b.extend_from_slice(&[3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]);
        b.extend_from_slice(&[0xFF, SOS, 0x00, 0x02, 0x12, 0x34, 0xFF, EOI]);
        b
    }

    #[test]
    fn reads_the_frame_and_strips_app_segments() {
        let bytes = minimal(300, 200);
        let header = parse(&bytes).unwrap();
        assert_eq!((header.width, header.height), (300, 200));
        assert_eq!(header.sampling, vec![(2, 2), (1, 1), (1, 1)]);
        assert!(!header.progressive);
        let stripped = strip_metadata(&bytes).unwrap();
        assert_eq!(stripped.len(), bytes.len() - 6);
        assert_eq!(&stripped[..4], &[0xFF, SOI, 0xFF, 0xC0]);
        assert!(stripped.ends_with(&[0x12, 0x34, 0xFF, EOI]));
    }

    #[test]
    fn rejects_a_second_frame_and_unsupported_frames() {
        let mut two = minimal(10, 10);
        let sof = two[8..27].to_vec();
        two.splice(27..27, sof);
        assert_eq!(parse(&two), None);
        for marker in [0xC3, 0xC5, 0xC9, 0xCF] {
            let mut bytes = minimal(10, 10);
            bytes[9] = marker;
            assert_eq!(parse(&bytes), None, "{marker:#x}");
        }
    }

    #[test]
    fn the_first_scan_must_run_into_the_final_eoi() {
        assert!(ends_with_first_scan(&minimal(10, 10)));

        // Stuffing, restart markers and fill bytes stay inside the scan.
        let mut scan = minimal(10, 10);
        let eoi = scan.len() - 2;
        scan.splice(eoi..eoi, [0xFF, 0x00, 0x56, 0xFF, 0xD3, 0x78, 0xFF, 0xFF]);
        assert!(ends_with_first_scan(&scan));

        let mut trailing = minimal(10, 10);
        trailing.extend_from_slice(b"junk");
        trailing.extend_from_slice(&[0xFF, EOI]);
        assert!(!ends_with_first_scan(&trailing));

        let mut second_scan = minimal(10, 10);
        let eoi = second_scan.len() - 2;
        second_scan.splice(eoi..eoi, [0xFF, SOS, 0x00, 0x02, 0x9A]);
        assert!(!ends_with_first_scan(&second_scan));

        let whole = minimal(10, 10);
        for end in 0..whole.len() {
            assert!(!ends_with_first_scan(&whole[..end]), "cut at {end}");
        }
    }

    #[test]
    fn truncated_or_short_segments_are_refused() {
        let bytes = minimal(10, 10);
        for end in 0..bytes.len() - 6 {
            assert_eq!(parse(&bytes[..end]), None, "cut at {end}");
        }
        let mut short = minimal(10, 10);
        short[11] = 0x08; // SOF length too short for 3 components
        assert_eq!(parse(&short), None);
    }
}
