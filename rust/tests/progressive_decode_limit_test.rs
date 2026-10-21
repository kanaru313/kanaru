//! A progressive JPEG whose coefficients alone exceed the decode limit gets
//! no thumbnail, and nothing close to that memory is allocated for it.
//! Alone in its test binary: it reads the process's peak memory, which
//! other tests running alongside would disturb.

use image::ImageFormat;
use rust_lib_kanaru::cover_thumbnail::{make_jpeg, MAX_DECODE_BYTES};

/// Peak resident memory of this process, in bytes.
fn peak_rss() -> u64 {
    let status = std::fs::read_to_string("/proc/self/status").unwrap();
    let line = status.lines().find(|l| l.starts_with("VmHWM:")).unwrap();
    let kib: u64 = line.split_whitespace().nth(1).unwrap().parse().unwrap();
    kib * 1024
}

#[cfg(target_os = "linux")]
#[test]
fn progressive_jpeg_over_the_decode_limit_is_refused_without_decoding() {
    // 4096² 4:4:4: 96 MiB of coefficients, plus 48 MiB of output.
    let side = 4096u16;
    let jpeg = {
        let pixels = vec![120u8; usize::from(side) * usize::from(side) * 3];
        let mut out = Vec::new();
        let mut encoder = jpeg_encoder::Encoder::new(&mut out, 50);
        encoder.set_progressive(true);
        encoder.set_sampling_factor(jpeg_encoder::SamplingFactor::F_1_1);
        encoder
            .encode(&pixels, side, side, jpeg_encoder::ColorType::Rgb)
            .unwrap();
        out
    };
    // Reset the peak to what is resident now.
    std::fs::write("/proc/self/clear_refs", "5").unwrap();
    let before = peak_rss();
    let thumbnail = make_jpeg(&jpeg, ImageFormat::Jpeg);
    let grew = peak_rss() - before;
    assert_eq!(thumbnail, None);
    assert!(grew < MAX_DECODE_BYTES / 4, "peak grew by {} MiB", grew >> 20);
}
