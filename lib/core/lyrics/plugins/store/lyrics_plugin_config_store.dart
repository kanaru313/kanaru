import 'dart:convert';

import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../../../secrets/secret_store.dart';
import '../lyrics_plugin_record.dart';
import '../package/plugin_manifest.dart';
import 'plugin_config_schema_codec.dart';
import 'plugin_config_values.dart';
import 'plugin_secret_cache.dart';

export 'plugin_config_values.dart' show PluginConfigWrite;

final _log = Logger('lyrics_plugins');

/// Config values of the plugins. Non-secret values live in
/// `lyrics_plugin_data.config_values`; secret ones only in the [SecretStore]
/// under `lyrics_plugin.<installId>.<key>`. The form (which key is secret) is
/// always the record's current one, so a value left behind by a form change
/// is never read.
class LyricsPluginConfigStore {
  LyricsPluginConfigStore(this._db, Future<SecretStore> Function() secrets)
    : _secrets = PluginSecretCache(secrets);

  final LibraryDatabase _db;
  final PluginSecretCache _secrets;

  /// Sets [key] to [value] (a `String`, or a `bool` for a toggle). A null or
  /// empty string removes the value, so the field's default applies again.
  Future<PluginConfigWrite> setValue(
    String installId,
    String key,
    Object? value,
  ) async {
    final record = await _live(installId);
    final field = record?.field(key);
    if (field == null) return PluginConfigWrite.unknownKey;
    final cleared = value == null || value == '';
    if (!cleared && !pluginValueFits(field, value)) {
      return PluginConfigWrite.invalidValue;
    }
    if (isSecretField(field)) {
      final name = lyricsPluginSecretName(installId, key);
      try {
        cleared
            ? await _secrets.delete(name)
            : await _secrets.write(name, value as String);
      } on Object catch (error) {
        _log.warning('Secret write failed: ${error.runtimeType}');
        return PluginConfigWrite.secretStoreFailed;
      }
      return PluginConfigWrite.written;
    }
    final values = await _stored(installId);
    cleared ? values.remove(key) : values[key] = value;
    return _save(installId, values);
  }

  /// Everything a script may read, as strings: stored values, then the
  /// form's defaults for the rest, then secrets. A toggle reads `true` or
  /// `false`. Never throws for an unusable secret store (those read empty).
  Future<Map<String, String>> configForRun(String installId) async {
    final record = await _live(installId);
    if (record == null) return const {};
    final stored = await _stored(installId);
    final out = <String, String>{};
    for (final field in record.config) {
      if (isSecretField(field)) {
        final secret = await _secrets.read(
          lyricsPluginSecretName(installId, field.key),
        );
        if (secret != null) out[field.key] = secret;
        continue;
      }
      final value = stored[field.key] ?? field.defaultValue;
      if (value != null && pluginValueFits(field, value)) {
        out[field.key] = '$value';
      }
    }
    return out;
  }

  /// The non-secret values as stored (what a form shows), by key.
  Future<Map<String, Object?>> storedValues(String installId) =>
      _stored(installId);

  /// Whether the secret of [key] has a value (for the form: filled or not).
  Future<bool> hasSecret(String installId, String key) async =>
      await _secrets.read(lyricsPluginSecretName(installId, key)) != null;

  /// Removes the secret of every secret field of [schema]. Failures are
  /// logged (error type only) and do not stop the rest.
  /// Returns whether every delete succeeded.
  Future<bool> deleteSecretsOf(
    String installId,
    List<PluginConfigField> schema,
  ) async {
    var all = true;
    for (final field in schema.where(isSecretField)) {
      all &= await deleteSecret(installId, field.key);
    }
    return all;
  }

  Future<bool> deleteSecret(String installId, String key) async {
    try {
      await _secrets.delete(lyricsPluginSecretName(installId, key));
      return true;
    } on Object catch (error) {
      _log.warning('Secret delete failed: ${error.runtimeType}');
      return false;
    }
  }

  /// Moves values to follow a form change from [before] to [after]: a key
  /// that became secret moves from the database to the secret store, one that
  /// stopped being secret loses its store entry, a removed secret key loses
  /// its entry, and a stored value that no longer fits its field is dropped.
  Future<void> adaptToForm(
    String installId,
    List<PluginConfigField> before,
    List<PluginConfigField> after,
  ) async {
    final values = await _stored(installId);
    var changed = false;
    for (final old in before) {
      final now = after.where((f) => f.key == old.key).firstOrNull;
      if (isSecretField(old) && (now == null || !isSecretField(now))) {
        await deleteSecret(installId, old.key);
      }
      if (now != null && !isSecretField(old) && isSecretField(now)) {
        final value = values[old.key];
        if (value is String && value.isNotEmpty) {
          try {
            await _secrets.write(
              lyricsPluginSecretName(installId, old.key),
              value,
            );
          } on Object catch (error) {
            _log.warning('Secret move failed: ${error.runtimeType}');
            continue; // the value is dropped below with the other secret keys
          }
        }
        changed |= values.remove(old.key) != null;
      }
    }
    for (final key in values.keys.toList()) {
      final field = after.where((f) => f.key == key).firstOrNull;
      if (field == null ||
          isSecretField(field) ||
          !pluginValueFits(field, values[key])) {
        values.remove(key);
        changed = true;
      }
    }
    if (changed) await _save(installId, values);
  }

  Future<LyricsPluginRecord?> _live(String installId) async {
    final row = await _db.lyricsPluginById(installId);
    if (row == null || row.removedAt != null) return null;
    return LyricsPluginRecord.fromRow(row);
  }

  Future<Map<String, Object?>> _stored(String installId) async {
    final row = await _db.lyricsPluginDataFor(installId);
    if (row == null) return {};
    try {
      final value = jsonDecode(row.configValues);
      if (value is Map<String, dynamic>) return {...value};
    } on FormatException {
      // Unreadable text counts as no values.
    }
    return {};
  }

  Future<PluginConfigWrite> _save(
    String installId,
    Map<String, Object?> values,
  ) async => switch (await _db.setLyricsPluginConfigValues(installId, values)) {
    LyricsPluginWrite.written => PluginConfigWrite.written,
    LyricsPluginWrite.tooLarge => PluginConfigWrite.tooLarge,
    LyricsPluginWrite.skipped => PluginConfigWrite.unknownKey,
  };
}
