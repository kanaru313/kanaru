//! A baseline JPEG 8192 px on a side is decoded scaled down, row by row, and
//! needs next to no memory beyond the thumbnail. Alone in its test binary: it
//! reads the process's peak memory, which other tests running alongside would
//! disturb.

use image::ImageFormat;
use rust_lib_kanaru::cover_thumbnail::make_jpeg;

/// Peak resident memory of this process, in bytes.
fn peak_rss() -> u64 {
    let status = std::fs::read_to_string("/proc/self/status").unwrap();
    let line = status.lines().find(|l| l.starts_with("VmHWM:")).unwrap();
    let kib: u64 = line.split_whitespace().nth(1).unwrap().parse().unwrap();
    kib * 1024
}

#[cfg(target_os = "linux")]
#[test]
fn baseline_jpeg_8192_square_decodes_scaled_within_a_few_mib() {
    let side = 8192u16;
    let jpeg = {
        // A smooth ramp: a realistic few MiB of entropy-coded data.
        let pixels: Vec<u8> = (0..usize::from(side) * usize::from(side) * 3)
            .map(|i| (i / 997) as u8)
            .collect();
        let mut out = Vec::new();
        let mut encoder = jpeg_encoder::Encoder::new(&mut out, 70);
        encoder.set_sampling_factor(jpeg_encoder::SamplingFactor::F_2_2);
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
    assert!(grew < 16 << 20, "peak grew by {} MiB", grew >> 20);
    let size = image::load_from_memory(&thumbnail.unwrap())
        .unwrap()
        .into_rgb8()
        .dimensions();
    assert_eq!(size, (512, 512));
}
