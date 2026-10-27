import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'secret_store.dart';

final _log = Logger('secrets');

const _fileName = 'secrets.json';

/// Makes [path] readable and writable by its owner only.
typedef ChmodOwnerOnly = Future<void> Function(String path);

Future<void> _chmod600(String path) async {
  final ProcessResult result;
  try {
    result = await Process.run('chmod', ['600', path]);
  } on ProcessException {
    throw const FileSystemException('chmod is not available');
  }
  if (result.exitCode != 0) {
    throw const FileSystemException('chmod 600 failed');
  }
}

/// Fallback for systems without a Secret Service: a JSON object in
/// `<data dir>/secrets.json`, mode `0600`. The data directory is used, not the
/// config one, because config directories are often symlinked into dotfile
/// repositories. The file is plain text, so the UI warns when it is in use.
class SecretFileStore implements SecretStore {
  SecretFileStore(String dataDir, {this._chmod = _chmod600})
    : _dir = dataDir,
      _path = '$dataDir/$_fileName';

  final String _dir;
  final String _path;
  final ChmodOwnerOnly _chmod;
  Future<void> _queue = Future.value();
  bool _modeWasFixed = false;

  /// An existing file was readable by group or others and has been tightened.
  bool get modeWasFixed => _modeWasFixed;

  @override
  Future<String?> read(String key) => _serial(() async {
    await _sweepStaleTemps();
    return (await _load())?[key];
  });

  @override
  Future<void> write(String key, String value) => _serial(() async {
    await _sweepStaleTemps();
    final values = await _load() ?? {};
    values[key] = value;
    await _save(values);
  });

  @override
  Future<void> delete(String key) => _serial(() async {
    await _sweepStaleTemps();
    final values = await _load();
    // A file that cannot be read has nothing worth keeping.
    if (values != null && values.remove(key) == null) return;
    if (values == null || values.isEmpty) {
      await _guardIo(() => File(_path).delete());
    } else {
      await _save(values);
    }
  });

  /// Runs [action] after the ones before it, so reads and writes never
  /// overlap (they share the temp file name).
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// The stored values; empty when there is no file, `null` when the file is
  /// not a JSON object.
  Future<Map<String, String>?> _load() async {
    final file = File(_path);
    final String text;
    try {
      if (!await file.exists()) return {};
      await _tightenMode();
      text = await file.readAsString();
    } on FileSystemException catch (error) {
      throw _ioError(error);
    }
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, Object?>) return null;
      return {
        for (final MapEntry(:key, :value) in json.entries)
          if (value is String) key: value,
      };
    } on FormatException {
      _log.warning('The secrets file is not valid JSON; ignoring it');
      return null;
    }
  }

  Future<void> _tightenMode() async {
    if (await FileSystemEntity.isLink(_path)) {
      // chmod would change the link's target, which is not ours.
      _log.warning('The secrets file is a symbolic link; leaving its mode');
      return;
    }
    final stat = await FileStat.stat(_path);
    if (stat.mode & 0x3F == 0) return;
    await _chmod(_path);
    _modeWasFixed = true;
    _log.warning('The secrets file was readable by others; mode set to 600');
  }

  Future<void> _save(Map<String, String> values) async {
    final temp = '$_path.$pid.tmp';
    await _guardIo(() async {
      await Directory(_dir).create(recursive: true);
      final file = File(temp);
      if (await file.exists()) await file.delete();
      await file.create(exclusive: true);
      try {
        await _chmod(temp);
        if ((await FileStat.stat(temp)).mode & 0x3F != 0) {
          throw const FileSystemException('could not restrict file mode');
        }
        await file.writeAsString(jsonEncode(values), flush: true);
        await file.rename(_path);
      } on Object {
        if (await file.exists()) await file.delete();
        rethrow;
      }
    });
  }

  /// Temp files a crashed write left behind. They may hold a secret.
  Future<void> _sweepStaleTemps() async {
    final dir = Directory(_dir);
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        final name = entity.uri.pathSegments.last;
        if (entity is File &&
            name.startsWith('$_fileName.') &&
            name.endsWith('.tmp')) {
          await entity.delete();
        }
      }
    } on FileSystemException catch (error) {
      _log.warning('Could not remove old temp files: ${error.message}');
    }
  }

  Future<void> _guardIo(Future<void> Function() action) async {
    try {
      await action();
    } on FileSystemException catch (error) {
      throw _ioError(error);
    }
  }

  // Message and OS error only: never the path's content or a value.
  SecretStoreException _ioError(FileSystemException error) =>
      SecretStoreException(SecretStoreFailure.io, error.message);
}
