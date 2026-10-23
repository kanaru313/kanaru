//! Blending over black and resizing on the decoded buffer (in its own channel
//! layout) gives the thumbnail that converting to RGB first, then resizing,
//! gave.

use std::io::Cursor;

use fast_image_resize as fir;
use image::{
    DynamicImage, GenericImageView, GrayAlphaImage, GrayImage, ImageBuffer, ImageFormat, Luma,
    LumaA, Rgb, RgbImage, Rgba, RgbaImage,
};
use rust_lib_kanaru::cover_thumbnail::make_jpeg;

const WIDTH: u32 = 1500;
const HEIGHT: u32 = 1100;

fn png(image: &DynamicImage) -> Vec<u8> {
    let mut out = Cursor::new(Vec::new());
    image.write_to(&mut out, ImageFormat::Png).unwrap();
    out.into_inner()
}

/// The thumbnail the way the converting code made it: blend into an RGB
/// image, resize that as RGB, encode with the same settings.
fn reference(image: &DynamicImage) -> Vec<u8> {
    let rgb: RgbImage = if image.color().has_alpha() {
        let rgba = image.to_rgba8();
        RgbImage::from_fn(rgba.width(), rgba.height(), |x, y| {
            let [r, g, b, a] = rgba.get_pixel(x, y).0;
            let blend = |c: u8| ((u16::from(c) * u16::from(a) + 127) / 255) as u8;
            Rgb([blend(r), blend(g), blend(b)])
        })
    } else {
        image.to_rgb8()
    };
    let (new_width, new_height) = (
        512,
        (f64::from(HEIGHT) * 512.0 / f64::from(WIDTH)).round() as u32,
    );
    let source = fir::images::ImageRef::new(
        rgb.width(),
        rgb.height(),
        rgb.as_raw(),
        fir::PixelType::U8x3,
    )
    .unwrap();
    let mut target = fir::images::Image::new(new_width, new_height, fir::PixelType::U8x3);
    let options = fir::ResizeOptions::new()
        .resize_alg(fir::ResizeAlg::Convolution(fir::FilterType::Lanczos3));
    fir::Resizer::new()
        .resize(&source, &mut target, &options)
        .unwrap();
    let mut out = Vec::new();
    let mut encoder = jpeg_encoder::Encoder::new(&mut out, 85);
    encoder.set_sampling_factor(jpeg_encoder::SamplingFactor::F_1_1);
    encoder
        .encode(
            &target.into_vec(),
            new_width as u16,
            new_height as u16,
            jpeg_encoder::ColorType::Rgb,
        )
        .unwrap();
    out
}

/// Largest difference of one channel between two JPEGs, decoded.
fn max_difference(a: &[u8], b: &[u8]) -> u8 {
    let a = image::load_from_memory(a).unwrap().into_rgb8();
    let b = image::load_from_memory(b).unwrap().into_rgb8();
    assert_eq!(a.dimensions(), b.dimensions());
    a.as_raw()
        .iter()
        .zip(b.as_raw())
        .map(|(x, y)| x.abs_diff(*y))
        .max()
        .unwrap()
}

fn check(name: &str, image: DynamicImage, tolerance: u8) {
    let bytes = png(&image);
    let made = make_jpeg(&bytes, ImageFormat::Png).unwrap();
    let expected = reference(&image);
    let difference = max_difference(&made, &expected);
    assert!(difference <= tolerance, "{name}: differs by {difference}");
}

#[test]
fn rgba_with_varying_alpha_matches_the_converting_path() {
    // Alpha from fully clear to opaque, edges and noise in the colours.
    let image = RgbaImage::from_fn(WIDTH, HEIGHT, |x, y| {
        let alpha = ((x * 255) / WIDTH) as u8;
        let noise = (x.wrapping_mul(2654435761) ^ y.wrapping_mul(40503)) as u8;
        Rgba([
            (x ^ y) as u8,
            noise,
            if x % 97 < 3 { 255 } else { 20 },
            alpha,
        ])
    });
    check("rgba8", DynamicImage::ImageRgba8(image), 0);
}

#[test]
fn gray_and_gray_alpha_match_the_converting_path() {
    let gray = GrayImage::from_fn(WIDTH, HEIGHT, |x, y| Luma([(x.wrapping_mul(7) ^ y) as u8]));
    check("luma8", DynamicImage::ImageLuma8(gray), 1);
    let gray_alpha = GrayAlphaImage::from_fn(WIDTH, HEIGHT, |x, y| {
        LumaA([(x.wrapping_mul(7) ^ y) as u8, ((y * 255) / HEIGHT) as u8])
    });
    check("luma_alpha8", DynamicImage::ImageLumaA8(gray_alpha), 1);
}

#[test]
fn rgb_and_sixteen_bit_images_match_the_converting_path() {
    let rgb = RgbImage::from_fn(WIDTH, HEIGHT, |x, y| {
        Rgb([(x ^ y) as u8, (x * 3) as u8, (y * 5) as u8])
    });
    check("rgb8", DynamicImage::ImageRgb8(rgb), 0);
    let rgba16: ImageBuffer<Rgba<u16>, Vec<u16>> = ImageBuffer::from_fn(WIDTH, HEIGHT, |x, y| {
        Rgba([
            (x * 40) as u16,
            (y * 50) as u16,
            ((x ^ y) * 20) as u16,
            (x * 43) as u16,
        ])
    });
    check("rgba16", DynamicImage::ImageRgba16(rgba16), 1);
}

#[test]
fn a_small_image_with_alpha_is_blended_and_not_resized() {
    let image = RgbaImage::from_fn(100, 80, |x, _| Rgba([200, 100, 50, (x * 2) as u8]));
    let bytes = png(&DynamicImage::ImageRgba8(image));
    let made = image::load_from_memory(&make_jpeg(&bytes, ImageFormat::Png).unwrap()).unwrap();
    assert_eq!(made.dimensions(), (100, 80));
    let [r, ..] = made.to_rgb8().get_pixel(0, 40).0;
    assert!(r < 8, "fully transparent column should be black, got {r}");
}
