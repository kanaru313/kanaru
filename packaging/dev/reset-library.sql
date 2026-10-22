-- Clears the scanned library from library.db and keeps user data.
-- Run by `make reset-library` with the sqlite3 CLI (>= 3.35, FTS5 enabled).
--
-- Removed: library_roots, tracks, track_artists, and the track_search index
-- rows (the tracks_search_delete trigger empties the index per deleted track).
-- Kept: plays, play_stats, playlists, playlist_entries. They reference tracks
-- by path, not by foreign key, so nothing below can reach them.
-- Update this list when a table derived from the scan is added.

PRAGMA foreign_keys = ON;
PRAGMA recursive_triggers = ON;

BEGIN IMMEDIATE;
-- The delete trigger removes each track's tokens by value. If the index has
-- drifted from `tracks` (a crash, a bug, a hand edit), those deletes fail with
-- "database disk image is malformed" and the reset would be impossible exactly
-- when it is needed. Rebuilding first makes the index match `tracks` again.
INSERT INTO track_search(track_search) VALUES ('rebuild');
DELETE FROM track_artists;
DELETE FROM tracks;
DELETE FROM library_roots;
COMMIT;

-- Fails (non-zero exit) if the full-text index no longer matches `tracks`.
INSERT INTO track_search(track_search, rank) VALUES ('integrity-check', 1);
