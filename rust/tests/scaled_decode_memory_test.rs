//! A large progressive JPEG decoded scaled must stay within the decode
//! limit, although it keeps every coefficient of the full image. Alone in
//! its test binary: it reads the process's peak memory, which other tests
//! running alongside would disturb.

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
fn large_progressive_jpeg_stays_within_the_decode_limit() {
    // 4096×3000 4:2:0: about 35 MiB of coefficients, under the 64 MiB limit,
    // for a 512×375 result.
    let (width, height) = (4096u16, 3000u16);
    let jpeg = {
        let pixels = vec![77u8; usize::from(width) * usize::from(height) * 3];
        let mut out = Vec::new();
        let mut encoder = jpeg_encoder::Encoder::new(&mut out, 50);
        encoder.set_progressive(true);
        encoder.set_sampling_factor(jpeg_encoder::SamplingFactor::F_2_2);
        encoder
            .encode(&pixels, width, height, jpeg_encoder::ColorType::Rgb)
            .unwrap();
        out
    };
    // Reset the peak to what is resident now.
    std::fs::write("/proc/self/clear_refs", "5").unwrap();
    let before = peak_rss();
    let thumbnail = make_jpeg(&jpeg, ImageFormat::Jpeg);
    let grew = peak_rss() - before;
    assert!(grew < MAX_DECODE_BYTES, "peak grew by {} MiB", grew >> 20);
    let size = image::load_from_memory(&thumbnail.unwrap())
        .unwrap()
        .into_rgb8()
        .dimensions();
    assert_eq!(size, (512, 375));
}
