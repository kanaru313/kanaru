//! Cover colors from thumbnails: what they are for plain images, and that a
//! bad key or a bad file fails only its own entry, without hanging.

mod common;

use std::fs;
use std::path::Path;
use std::sync::mpsc;
use std::time::Duration;

use common::*;
use image::{DynamicImage, ImageFormat, RgbImage};
use material_colors::color::Argb;
use material_colors::quantize::QuantizerResult;
use rust_lib_kanaru::api::cover_colors::{
    extract_cover_colors, CoverColorResult, CoverColorStatus,
};
use rust_lib_kanaru::cover_colors::{
    colors_of_pixels, colors_of_thumbnail, is_cover_key, seed_of, MAX_THUMBNAIL_BYTES,
};

/// A key for `n`, shaped like a real cover key.
fn key(n: u32) -> String {
    let hash = format!("{n:064x}");
    format!("{}/{hash}.jpg", &hash[..2])
}

/// Writes `bytes` as the thumbnail of `key` under `dir`.
fn put(dir: &Path, key: &str, bytes: &[u8]) {
    let path = dir.join(key);
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, bytes).unwrap();
}

fn rgb_jpeg(image: RgbImage) -> Vec<u8> {
    encode(DynamicImage::ImageRgb8(image), ImageFormat::Jpeg)
}

fn solid(width: u32, height: u32, rgb: [u8; 3]) -> Vec<u8> {
    rgb_jpeg(RgbImage::from_pixel(width, height, image::Rgb(rgb)))
}

fn channels(argb: u32) -> (i32, i32, i32) {
    (
        (argb >> 16 & 0xFF) as i32,
        (argb >> 8 & 0xFF) as i32,
        (argb & 0xFF) as i32,
    )
}

/// `jpeg` with the frame header patched to claim `width`×`height`.
fn claiming(jpeg: &[u8], width: u16, height: u16) -> Vec<u8> {
    let mut bytes = jpeg.to_vec();
    let sof = bytes
        .windows(2)
        .position(|w| w[0] == 0xFF && (w[1] == 0xC0 || w[1] == 0xC2))
        .expect("frame header");
    bytes[sof + 5..sof + 7].copy_from_slice(&height.to_be_bytes());
    bytes[sof + 7..sof + 9].copy_from_slice(&width.to_be_bytes());
    bytes
}

fn one(dir: &Path, key: &str) -> CoverColorResult {
    let mut results = extract_cover_colors(
        dir.to_string_lossy().into_owned(),
        vec![key.to_owned()],
        false,
    );
    assert_eq!(results.len(), 1);
    results.remove(0)
}

#[test]
fn a_red_cover_gives_a_red_seed_and_palette() {
    let colors = colors_of_thumbnail(&solid(64, 64, [200, 30, 40])).expect("colors");
    let (r, g, b) = channels(colors.seed);
    assert_eq!(colors.seed >> 24, 0xFF, "seed is opaque");
    assert!(r > g + 60 && r > b + 60, "seed {:08x}", colors.seed);
    assert_eq!(colors.palette.len(), 1, "palette {:08x?}", colors.palette);
    let (r, g, b) = channels(colors.palette[0]);
    assert!(r > g + 60 && r > b + 60, "palette {:08x?}", colors.palette);
}

#[test]
fn a_gray_cover_has_no_seed_but_a_palette() {
    let colors = colors_of_thumbnail(&solid(64, 64, [128, 128, 128])).expect("colors");
    assert_eq!(colors.seed, 0);
    assert!(!colors.palette.is_empty());
    assert!(colors.palette.iter().all(|c| c >> 24 == 0xFF));
}

#[test]
fn a_gray_gradient_has_no_seed() {
    let image = RgbImage::from_fn(128, 128, |x, _| {
        let v = (x * 2) as u8;
        image::Rgb([v, v, v])
    });
    let colors = colors_of_thumbnail(&rgb_jpeg(image)).expect("colors");
    assert_eq!(colors.seed, 0);
    assert!(colors.palette.len() > 1, "palette {:08x?}", colors.palette);
}

#[test]
fn the_palette_puts_the_most_common_color_first() {
    let image = RgbImage::from_fn(100, 100, |x, _| {
        if x < 75 {
            image::Rgb([30, 180, 40])
        } else {
            image::Rgb([30, 40, 200])
        }
    });
    let colors = colors_of_thumbnail(&rgb_jpeg(image)).expect("colors");
    let (r, g, b) = channels(colors.palette[0]);
    assert!(g > r + 60 && g > b + 60, "palette {:08x?}", colors.palette);
    assert!(
        colors.palette.iter().any(|&c| {
            let (r, g, b) = channels(c);
            b > r + 60 && b > g + 60
        }),
        "palette {:08x?}",
        colors.palette
    );
}

#[test]
fn a_one_pixel_cover_does_not_panic() {
    let _ = colors_of_thumbnail(&solid(1, 1, [10, 200, 30]));
}

#[test]
fn a_large_thumbnail_is_sampled_down() {
    let colors = colors_of_thumbnail(&solid(512, 300, [20, 40, 210])).expect("colors");
    let (r, g, b) = channels(colors.seed);
    assert!(b > r + 60 && b > g + 60, "seed {:08x}", colors.seed);
}

#[test]
fn no_pixels_give_no_colors() {
    assert_eq!(colors_of_pixels(&[]), None);
}

#[test]
fn an_empty_cluster_map_never_reaches_score() {
    let empty = QuantizerResult {
        color_to_count: Default::default(),
        input_pixel_to_cluster_pixel: Default::default(),
    };
    assert_eq!(seed_of(&empty), 0);
    let mut zero = QuantizerResult {
        color_to_count: Default::default(),
        input_pixel_to_cluster_pixel: Default::default(),
    };
    zero.color_to_count.insert(Argb::new(255, 255, 0, 0), 0);
    assert_eq!(seed_of(&zero), 0);
}

#[test]
fn cover_keys_must_have_the_cache_shape() {
    assert!(is_cover_key(&key(0xab)));
    let good = key(0xab);
    for bad in [
        "../x.jpg".to_owned(),
        "ab/zz.jpg".to_owned(),
        good.to_uppercase(),
        good.replace(".jpg", ".png"),
        format!("ff/{}", &good[3..]),
        format!("{good}/x"),
        format!("/{good}"),
        String::new(),
    ] {
        assert!(!is_cover_key(&bad), "{bad}");
    }
}

#[test]
fn bad_keys_and_bad_files_fail_alone() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    // Next to the cover folder, so a key that escapes it would find it.
    put(root, "x.jpg", &solid(8, 8, [200, 0, 0]));
    let covers = root.join("covers");
    fs::create_dir_all(&covers).unwrap();

    let empty = key(1);
    put(&covers, &empty, b"");
    let png = key(2);
    put(&covers, &png, &png_bytes());
    let huge_header = key(3);
    put(
        &covers,
        &huge_header,
        &claiming(&solid(16, 16, [9, 9, 200]), 65535, 65535),
    );
    let too_wide = key(4);
    put(&covers, &too_wide, &solid(1024, 1024, [9, 200, 9]));
    let too_big = key(5);
    put(
        &covers,
        &too_big,
        &vec![0xFF; MAX_THUMBNAIL_BYTES as usize + 1],
    );
    let zero = key(6);
    fs::create_dir_all(covers.join(&zero[..2])).unwrap();
    std::os::unix::fs::symlink("/dev/zero", covers.join(&zero)).unwrap();
    let fifo = key(7);
    fs::create_dir_all(covers.join(&fifo[..2])).unwrap();
    mkfifo(&covers.join(&fifo));
    let truncated = key(8);
    let whole = solid(64, 64, [200, 30, 40]);
    put(&covers, &truncated, &whole[..whole.len() / 3]);
    let missing = key(9);
    let good = key(10);
    put(&covers, &good, &solid(32, 32, [200, 30, 40]));

    let keys = vec![
        "../x.jpg".to_owned(),
        "ab/zz.jpg".to_owned(),
        empty,
        png,
        huge_header,
        too_wide,
        too_big,
        zero,
        fifo,
        truncated,
        missing,
        good.clone(),
    ];
    let cover_dir = covers.to_string_lossy().into_owned();
    let (tx, rx) = mpsc::channel();
    let sent = keys.clone();
    std::thread::spawn(move || {
        tx.send(extract_cover_colors(cover_dir, sent, true))
            .unwrap()
    });
    let results = rx
        .recv_timeout(Duration::from_secs(20))
        .expect("no file may hang the batch");

    assert_eq!(
        results.iter().map(|r| r.key.as_str()).collect::<Vec<_>>(),
        keys.iter().map(String::as_str).collect::<Vec<_>>()
    );
    for result in &results[..results.len() - 1] {
        assert_eq!(result.status, CoverColorStatus::Failed, "{}", result.key);
        assert_eq!(result.seed, 0);
        assert!(result.palette.is_empty());
    }
    let last = results.last().unwrap();
    assert_eq!(
        (last.key.as_str(), last.status),
        (good.as_str(), CoverColorStatus::Done)
    );
}

fn png_bytes() -> Vec<u8> {
    png(16, 16, 40)
}

#[test]
fn batches_keep_their_order_on_either_thread() {
    let dir = tempfile::tempdir().unwrap();
    let keys: Vec<String> = (0..40).map(key).collect();
    for (i, key) in keys.iter().enumerate() {
        if i % 3 != 0 {
            let shade = (i * 5) as u8;
            put(dir.path(), key, &solid(24, 24, [shade, 200 - shade, 90]));
        }
    }
    let cover_dir = dir.path().to_string_lossy().into_owned();
    for background in [true, false] {
        let results = extract_cover_colors(cover_dir.clone(), keys.clone(), background);
        assert_eq!(
            results.iter().map(|r| r.key.clone()).collect::<Vec<_>>(),
            keys
        );
        for (i, result) in results.iter().enumerate() {
            let expected = if i % 3 == 0 {
                CoverColorStatus::Failed
            } else {
                CoverColorStatus::Done
            };
            assert_eq!(result.status, expected, "{i} background {background}");
        }
    }
    // Same input, same colors, wherever it ran.
    assert_eq!(
        extract_cover_colors(cover_dir.clone(), keys.clone(), true),
        extract_cover_colors(cover_dir, keys, false)
    );
}

#[test]
fn an_empty_cover_folder_fails_every_key() {
    let results = extract_cover_colors(String::new(), vec![key(1), key(2)], false);
    assert!(results
        .iter()
        .all(|r| r.status == CoverColorStatus::Failed && r.palette.is_empty()));
    assert_eq!(results.len(), 2);
}

#[test]
fn a_good_thumbnail_reports_done() {
    let dir = tempfile::tempdir().unwrap();
    let good = key(42);
    put(dir.path(), &good, &solid(48, 48, [220, 200, 20]));
    let result = one(dir.path(), &good);
    assert_eq!(result.status, CoverColorStatus::Done);
    assert_ne!(result.seed, 0);
    assert!(!result.palette.is_empty() && result.palette.len() <= 5);
}

/// Time per 512 px thumbnail, one thread, release-like build (`opt-level = 3`
/// in the dev profile). Run with `--ignored --nocapture`.
#[test]
#[ignore]
fn bench_colors_of_a_thumbnail() {
    let image = RgbImage::from_fn(512, 512, |x, y| {
        image::Rgb([(x / 2) as u8, (y / 2) as u8, ((x + y) / 4) as u8])
    });
    let bytes = rgb_jpeg(image);
    let runs = 50;
    let start = std::time::Instant::now();
    for _ in 0..runs {
        assert!(colors_of_thumbnail(&bytes).is_some());
    }
    let each = start.elapsed() / runs;
    println!("colors of a 512 px thumbnail: {each:?}");
}
