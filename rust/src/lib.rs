//! Native side of Kanaru: reads audio tags for the library indexer and exposes
//! them to Dart through flutter_rust_bridge.

pub mod api;
mod frb_generated;
pub mod tag_mapping;
pub mod tag_reader;
