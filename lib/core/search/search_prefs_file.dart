import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../paths/app_directories.dart';
import 'search_fields.dart';
import 'search_prefs.dart';

final _log = Logger('search');

/// Version written to the file. A file with a higher one is read but never
/// overwritten in the session.
const searchPrefsFileVersion = 1;

/// `search_history.json` in Kanaru's data directory, or `null` when neither
/// `XDG_DATA_HOME` nor `HOME` gives one (the prefs then live in memory).
SearchPrefsFile? searchPrefsFileFor(Map<String, String> environment) {
  final directory = resolveDataDirectory(environment);
  return directory == null
      ? null
      : SearchPrefsFile('$directory/search_history.json');
}

/// Reads and writes the search prefs file.
///
/// Writes are atomic (temporary file next to the target, then rename; a
/// symlink is written through) and run one after another, so two quick saves
/// never land out of order. The last instance to write wins; instances are
/// not merged. Queries are private: they are never logged.
class SearchPrefsFile {
  SearchPrefsFile(this.path);

  final String path;

  bool _readOnly = false;
  Future<void> _queue = Future.value();

  /// Whether [save] does nothing for the rest of the session.
  bool get readOnly => _readOnly;

  /// The stored prefs, or defaults. Never throws. A file that is not a JSON
  /// object is renamed to `<path>.invalid` and defaults are used.
  Future<SearchPrefs> load() async {
    try {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) return const SearchPrefs();

      final Object? json;
      try {
        json = jsonDecode(
          _withoutBom(utf8.decode(await File(path).readAsBytes())),
        );
      } on FormatException {
        await _quarantine(isLink: type == FileSystemEntityType.link);
        return const SearchPrefs();
      }
      if (json is! Map<String, Object?>) {
        await _quarantine(isLink: type == FileSystemEntityType.link);
        return const SearchPrefs();
      }

      final version = json['version'];
      if (version is int && version > searchPrefsFileVersion) {
        _readOnly = true;
        _log.warning(
          'search_history.json has version $version, newer than '
          '$searchPrefsFileVersion: not saving changes this session',
        );
      }
      return decodeSearchPrefs(json);
    } catch (error) {
      _readOnly = true;
      _log.warning(
        'Could not read search_history.json (${_describe(error)}): using '
        'defaults, not saving changes this session',
      );
      return const SearchPrefs();
    }
  }

  /// Writes [prefs] after the saves already waiting. Never throws; a failure
  /// is logged. A read-only file skips the write.
  Future<void> save(SearchPrefs prefs) {
    if (_readOnly) return Future.value();
    final json = encodeSearchPrefs(prefs);
    return _queue = _queue.then((_) => _write(json));
  }

  Future<void> _write(Map<String, Object?> json) async {
    File? temporary;
    try {
      final target = await FileSystemEntity.isLink(path)
          ? await File(path).resolveSymbolicLinks()
          : path;
      await File(target).parent.create(recursive: true);
      temporary = File('$target.$pid.tmp');
      await temporary.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
        flush: true,
      );
      await temporary.rename(target);
    } catch (error) {
      _log.warning('Could not save search_history.json (${_describe(error)})');
      try {
        await temporary?.delete();
      } on FileSystemException {
        // Never created, or already renamed.
      }
    }
  }

  Future<void> _quarantine({required bool isLink}) async {
    // A symlink usually points into managed dotfiles: leave it alone.
    if (isLink) {
      _readOnly = true;
      _log.warning('search_history.json is not valid: using defaults');
      return;
    }
    try {
      await File(path).rename('$path.invalid');
      _log.warning(
        'search_history.json is not valid: moved it to '
        'search_history.json.invalid and using defaults',
      );
    } on FileSystemException catch (error) {
      _readOnly = true;
      _log.warning(
        'search_history.json is not valid and could not be moved aside '
        '(${_describe(error)}): using defaults',
      );
    }
  }
}

/// Prefs from a decoded file. A missing or wrong-typed key gives its default;
/// unknown field names and non-string or blank history entries are dropped.
SearchPrefs decodeSearchPrefs(Map<String, Object?> json) {
  final history = <String>[];
  final rawHistory = json['history'];
  if (rawHistory is List<Object?>) {
    for (final item in rawHistory) {
      if (item is! String) continue;
      final entry = SearchPrefs.cleanEntry(item);
      if (entry.isEmpty) continue;
      final key = entry.toLowerCase();
      if (history.any((old) => old.toLowerCase() == key)) continue;
      history.add(entry);
      if (history.length == searchHistoryLimit) break;
    }
  }

  final fields = <SearchField>{};
  final rawFields = json['fields'];
  if (rawFields is List<Object?>) {
    for (final item in rawFields) {
      for (final field in SearchField.values) {
        if (field.name == item) fields.add(field);
      }
    }
  }
  return fields.isEmpty
      ? SearchPrefs(history: history)
      : SearchPrefs(history: history, fields: Set.unmodifiable(fields));
}

Map<String, Object?> encodeSearchPrefs(SearchPrefs prefs) => {
  'version': searchPrefsFileVersion,
  'history': prefs.history,
  'fields': [
    // Enum order, so the file does not depend on the order of choosing.
    for (final field in SearchField.values)
      if (prefs.fields.contains(field)) field.name,
  ],
};

/// The error without the file's contents and without the full path.
String _describe(Object error) => switch (error) {
  FileSystemException(:final osError?) => osError.message,
  _ => error.runtimeType.toString(),
};

String _withoutBom(String text) =>
    text.startsWith('﻿') ? text.substring(1) : text;
