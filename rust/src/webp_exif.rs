//! EXIF orientation of a WebP, read without the WebP decoder.
//!
//! The decoder reserves a buffer of the length a chunk declares before it
//! reads any data, so a hostile file could ask for gigabytes. The walk here
//! works on the bytes already in memory and checks every declared length
//! against what is left of them; it allocates nothing.

use image::metadata::Orientation;

/// Prefix some writers put in front of the TIFF block of an `EXIF` chunk.
const EXIF_PREFIX: &[u8] = b"Exif\0\0";

/// The EXIF orientation (1–8) of a WebP file, or 1 when it has no `EXIF`
/// chunk, the chunk is damaged, or a chunk length runs past the end of
/// `bytes`.
pub fn orientation(bytes: &[u8]) -> u16 {
    exif_chunk(bytes)
        .map(|chunk| chunk.strip_prefix(EXIF_PREFIX).unwrap_or(chunk))
        .and_then(Orientation::from_exif_chunk)
        .map_or(1, |orientation| u16::from(orientation.to_exif()))
}

/// Payload of the first `EXIF` chunk. RIFF chunks are a four-byte name, a
/// little-endian `u32` length, the data, and one pad byte after odd lengths.
fn exif_chunk(bytes: &[u8]) -> Option<&[u8]> {
    let mut rest = bytes
        .strip_prefix(b"RIFF")?
        .get(4..)?
        .strip_prefix(b"WEBP")?;
    while let Some((header, after)) = rest.split_at_checked(8) {
        let name = &header[..4];
        let length = usize::try_from(u32::from_le_bytes(header[4..].try_into().ok()?)).ok()?;
        let data = after.get(..length)?;
        if name == b"EXIF" {
            return Some(data);
        }
        rest = after.get(length + length % 2..).unwrap_or_default();
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Big-endian TIFF block with one Orientation entry.
    fn tiff(orientation: u16) -> Vec<u8> {
        let mut tiff = b"MM\0\x2a\0\0\0\x08\0\x01\x01\x12\0\x03\0\0\0\x01".to_vec();
        tiff.extend_from_slice(&orientation.to_be_bytes());
        tiff.extend_from_slice(&[0; 6]);
        tiff
    }

    fn riff(chunks: &[(&[u8; 4], u32, &[u8])]) -> Vec<u8> {
        let mut out = b"RIFF\0\0\0\0WEBP".to_vec();
        for (name, declared, data) in chunks {
            out.extend_from_slice(*name);
            out.extend_from_slice(&declared.to_le_bytes());
            out.extend_from_slice(data);
            if data.len() % 2 == 1 {
                out.push(0);
            }
        }
        out
    }

    fn sized<'a>(name: &'a [u8; 4], data: &'a [u8]) -> (&'a [u8; 4], u32, &'a [u8]) {
        (name, data.len() as u32, data)
    }

    #[test]
    fn reads_the_orientation_after_other_chunks() {
        let exif = tiff(6);
        let odd = [1u8, 2, 3];
        let file = riff(&[
            sized(b"VP8X", &[0; 10]),
            sized(b"ICCP", &odd),
            sized(b"EXIF", &exif),
        ]);
        assert_eq!(orientation(&file), 6);
    }

    #[test]
    fn accepts_the_exif_prefix() {
        let exif = [EXIF_PREFIX, &tiff(8)].concat();
        assert_eq!(orientation(&riff(&[sized(b"EXIF", &exif)])), 8);
    }

    #[test]
    fn no_exif_or_not_a_webp_is_upright() {
        assert_eq!(orientation(&riff(&[sized(b"VP8X", &[0; 10])])), 1);
        assert_eq!(orientation(b"RIFF\0\0\0\0WAVEfmt "), 1);
        assert_eq!(orientation(b""), 1);
        assert_eq!(orientation(&riff(&[sized(b"EXIF", b"garbage!")])), 1);
    }

    #[test]
    fn lengths_past_the_end_are_upright() {
        let exif = tiff(6);
        for declared in [exif.len() as u32 + 1, 1 << 30, u32::MAX] {
            let file = riff(&[(b"EXIF", declared, &exif)]);
            assert_eq!(orientation(&file), 1, "{declared}");
        }
        // A skipped chunk that claims more than the file holds.
        let file = riff(&[(b"ICCP", u32::MAX, &[0; 4])]);
        assert_eq!(orientation(&file), 1);
        // Cut inside a chunk header.
        assert_eq!(orientation(b"RIFF\0\0\0\0WEBPEXI"), 1);
    }
}
