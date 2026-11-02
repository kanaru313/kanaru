/// What the JSON files under the app's directories (settings, playback
/// session, search history) share when they are read and logged.
library;

import 'dart:io';

/// [error] without the file's contents (a [FormatException] message quotes
/// them) and without the full path: fit for a log line.
String describeFileError(Object error) => switch (error) {
  FileSystemException(:final osError?) => osError.message,
  _ => error.runtimeType.toString(),
};

/// Editors on some systems prepend a byte order mark, which JSON rejects.
String withoutBom(String text) =>
    text.startsWith('\uFEFF') ? text.substring(1) : text;
