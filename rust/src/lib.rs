//! Native side of Kanaru: reads audio tags and cover art for the library
//! indexer and exposes them to Dart through flutter_rust_bridge.

pub mod api;
pub mod cover_art;
pub mod cover_batch;
pub mod cover_cache;
pub mod cover_colors;
mod cover_decode_limits;
pub mod cover_thumbnail;
mod frb_generated;
pub mod jpeg_header;
pub mod tag_batch;
pub mod tag_mapping;
pub mod tag_reader;
pub mod webp_exif;
