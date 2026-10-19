import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../paths/app_directories.dart';
import 'app_settings.dart';
import 'settings_codec.dart';

final _log = Logger('settings');

/// `settings.json` in Kanaru's config directory, or `null` when neither
/// `XDG_CONFIG_HOME` nor `HOME` gives one (settings then live in memory).
SettingsFile? settingsFileFor(Map<String, String> environment) {
  final directory = resolveConfigDirectory(environment);
  return directory == null ? null : SettingsFile('$directory/settings.json');
}

/// Reads and writes the settings file.
///
/// Writes are atomic: the JSON goes to a temporary file next to the real one
/// (next to its target when it is a symlink, so the link survives) and is
/// renamed over it. The temporary name includes the process id, so two
/// running instances never mix their bytes; the last one to write wins.
///
/// The file becomes read-only for the session when overwriting it could lose
/// something: it could not be read, or a newer Kanaru wrote it.
class SettingsFile {
  SettingsFile(this.path);

  final String path;

  bool _readOnly = false;
  Map<String, Object?> _unknownKeys = const {};

  /// Whether [save] does nothing for the rest of the session.
  bool get readOnly => _readOnly;

  /// The stored settings, or defaults. Never throws: it runs before the
  /// first frame, where an exception would leave an invisible window.
  ///
  /// A file that is not valid JSON is renamed to `settings.json.invalid`, so
  /// a broken hand edit is kept rather than overwritten.
  AppSettings load() {
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) return const AppSettings();

      final Object? json;
      try {
        json = jsonDecode(
          _withoutBom(utf8.decode(File(path).readAsBytesSync())),
        );
      } on FormatException {
        _quarantine(isLink: type == FileSystemEntityType.link);
        return const AppSettings();
      }
      if (json is! Map<String, Object?>) {
        _quarantine(isLink: type == FileSystemEntityType.link);
        return const AppSettings();
      }

      final decoded = decodeSettings(json);
      _unknownKeys = decoded.unknownKeys;
      if (decoded.version > settingsSchemaVersion) {
        _readOnly = true;
        _log.warning(
          'settings.json has version ${decoded.version}, newer than '
          '$settingsSchemaVersion: not saving changes this session',
        );
      }
      return decoded.settings;
    } catch (error) {
      _readOnly = true;
      _log.warning(
        'Could not read settings.json (${_describe(error)}): using defaults, '
        'not saving changes this session',
      );
      return const AppSettings();
    }
  }

  /// Writes [settings]. With [keepUnknown] false, keys this version does not
  /// know are dropped too. Never throws; failures are logged.
  ///
  /// Returns `false` when writing failed. A read-only file skips the write
  /// and returns `true`: [readOnly] reports that case.
  Future<bool> save(AppSettings settings, {bool keepUnknown = true}) async {
    if (_readOnly) return true;
    if (!keepUnknown) _unknownKeys = const {};
    File? temporary;
    try {
      final target = await FileSystemEntity.isLink(path)
          ? await File(path).resolveSymbolicLinks()
          : path;
      await File(target).parent.create(recursive: true);
      temporary = File('$target.$pid.tmp');
      final json = encodeSettings(settings, unknownKeys: _unknownKeys);
      await temporary.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
        flush: true,
      );
      await temporary.rename(target);
      return true;
    } catch (error) {
      _log.warning('Could not save settings.json (${_describe(error)})');
      try {
        await temporary?.delete();
      } on FileSystemException {
        // Never created, or already renamed.
      }
      return false;
    }
  }

  void _quarantine({required bool isLink}) {
    // A symlink usually points into managed dotfiles: leave it alone.
    if (isLink) {
      _readOnly = true;
      _log.warning('settings.json is not valid JSON: using defaults');
      return;
    }
    try {
      File(path).renameSync('$path.invalid');
      _log.warning(
        'settings.json is not valid JSON: moved it to settings.json.invalid '
        'and using defaults',
      );
    } on FileSystemException catch (error) {
      _readOnly = true;
      _log.warning(
        'settings.json is not valid JSON and could not be moved aside '
        '(${_describe(error)}): using defaults',
      );
    }
  }
}

/// The error without the file's contents (a [FormatException] message
/// quotes them) and without the full path.
String _describe(Object error) => switch (error) {
  FileSystemException(:final osError?) => osError.message,
  _ => error.runtimeType.toString(),
};

/// Editors on some systems prepend a byte order mark, which JSON rejects.
String _withoutBom(String text) =>
    text.startsWith('\uFEFF') ? text.substring(1) : text;
