import 'lyrics_provider.dart';

/// What [LrcSidecarWriter.write] did.
enum LrcWriteResult {
  /// The file was created (or replaced; the old one is in the trash).
  written,

  /// A `.lrc` or `.LRC` (or anything of that name) is already there with
  /// other content; it was not touched.
  exists,

  /// The file already holds exactly this text; nothing was written.
  identical,

  /// Instrumental, no text, or more text than a `.lrc` file may hold.
  nothingToWrite,

  /// The song is not a regular file inside an enabled library folder.
  outsideLibrary,

  /// The file system refused (read-only, permissions, full disk). Nothing
  /// was moved to the trash.
  failed,

  /// Replacing, and nothing could be moved to the trash (no trash on that
  /// disk, an error, an entry that is neither a file nor a link). The old
  /// files are as they were.
  trashFailed,

  /// The trash did not answer in time for the first old file. It may still
  /// have moved it later; the new file was not written.
  trashTimedOut,

  /// At least one old file is in the trash and the new one was not written.
  trashedNotWritten,
}

/// Writes the lyrics a user chose to save next to their song.
abstract interface class LrcSidecarWriter {
  /// Never throws and never deletes. Without [replace] an existing file is
  /// left alone (`exists` or `identical`); with it, old files go to the trash
  /// first. See [FileLrcSidecarWriter].
  Future<LrcWriteResult> write(
    String audioPath,
    LyricsBody body, {
    bool replace = false,
  });
}
