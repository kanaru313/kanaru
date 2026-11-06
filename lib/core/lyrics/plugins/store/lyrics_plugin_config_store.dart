import 'package:logging/logging.dart';

import '../../../database/library_database.dart';
import '../../../database/lyrics_plugin_queries.dart';
import '../../../plugin_runtime/plugin_runtime.dart';
import '../../../secrets/secret_store.dart';
import '../lyrics_plugin_record.dart';
import '../package/plugin_manifest.dart';
import 'plugin_config_migration.dart';
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

  /// Sets [key] to [value] (a string, number, bool, list or map, as the
  /// field's mode asks). A null or empty string removes the value, so the
  /// field's default applies again; an empty list or map is a value.
  Future<PluginConfigWrite> setValue(
    String installId,
    String key,
    Object? value,
  ) async {
    final record = await _live(installId);
    final declared = record?.field(key);
    if (declared == null) return PluginConfigWrite.unknownKey;
    final stored = await _stored(installId);
    // A choice the user added is a legal value of a `custom` select.
    final field = pluginEffectiveField(declared, stored);
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
    cleared ? stored.remove(key) : stored[key] = value;
    return _save(installId, stored);
  }

  /// Adds [value] (a model name) to the choices of the plugin's `custom`
  /// `model` select and selects it, in one write. A name that is already a
  /// choice (the plugin's or an earlier one) is only selected. The name is
  /// stripped of control characters and trimmed; empty, over
  /// [pluginCustomChoiceMaxValue] code points, a note over
  /// [pluginCustomChoiceMaxSubtitle], or a list that would pass
  /// [pluginConfigMaxItems] (the plugin's options and the user's together)
  /// is `invalidValue`.
  Future<PluginConfigWrite> addCustomModel(
    String installId,
    String value, {
    String? subtitle,
  }) async {
    final field = (await _live(installId))?.field(pluginModelKey);
    if (field == null || !field.custom) return PluginConfigWrite.unknownKey;
    final name = _cleanChoiceText(value);
    final note = subtitle == null ? '' : _cleanChoiceText(subtitle);
    if (name.isEmpty ||
        name.runes.length > pluginCustomChoiceMaxValue ||
        note.runes.length > pluginCustomChoiceMaxSubtitle) {
      return PluginConfigWrite.invalidValue;
    }
    final stored = await _stored(installId);
    final known = pluginEffectiveField(field, stored).options;
    if (!known.any((o) => o.value == name)) {
      if (known.length >= pluginConfigMaxItems) {
        return PluginConfigWrite.invalidValue;
      }
      final raw = stored[pluginCustomChoicesKey(field.key)];
      stored[pluginCustomChoicesKey(field.key)] = [
        if (raw is List) ...raw,
        {'value': name, if (note.isNotEmpty) 'subtitle': note},
      ];
    }
    stored[field.key] = name;
    return _save(installId, stored);
  }

  /// Removes [value] from the user's own choices of the `model` select. If it
  /// was the selected model the first remaining choice is selected, or the
  /// selection is cleared when none is left. A value that is not one of the
  /// user's choices is `invalidValue`.
  Future<PluginConfigWrite> removeCustomModel(
    String installId,
    String value,
  ) async {
    final field = (await _live(installId))?.field(pluginModelKey);
    if (field == null || !field.custom) return PluginConfigWrite.unknownKey;
    final stored = await _stored(installId);
    final listKey = pluginCustomChoicesKey(field.key);
    final raw = stored[listKey];
    final isCustom = pluginEffectiveField(
      field,
      stored,
    ).options.any((o) => o.custom && o.value == value);
    if (raw is! List || !isCustom) return PluginConfigWrite.invalidValue;
    final kept = [
      for (final item in raw)
        if (!(item is Map && item['value'] == value)) item,
    ];
    kept.isEmpty ? stored.remove(listKey) : stored[listKey] = kept;
    if (stored[field.key] == value) {
      final first = pluginEffectiveField(field, stored).options.firstOrNull;
      first == null
          ? stored.remove(field.key)
          : stored[field.key] = first.value;
    }
    return _save(installId, stored);
  }

  // Control characters out, ends trimmed.
  static String _cleanChoiceText(String text) =>
      text.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '').trim();

  /// Everything a script may read, typed: stored values, then the form's
  /// defaults for the rest, then secrets. A toggle reads a bool, a number a
  /// num, a list or multi-select a list, a map a map. A value that does not
  /// fit its field is left out. Never throws for an unusable secret store
  /// (those read absent).
  Future<PluginConfigMap> configForRun(String installId) async {
    final record = await _live(installId);
    if (record == null) return const {};
    final stored = await _stored(installId);
    final out = <String, Object>{};
    for (final field in record.config) {
      if (isSecretField(field)) {
        final secret = await _secrets.read(
          lyricsPluginSecretName(installId, field.key),
        );
        if (secret != null && pluginValueFits(field, secret)) {
          out[field.key] = secret;
        }
        continue;
      }
      // The effective field, so a model the user added reaches the script.
      final value = pluginEffectiveValue(
        pluginEffectiveField(field, stored),
        stored,
      );
      if (value != null) out[field.key] = _typed(value);
    }
    return out;
  }

  // A fitting value as the script reads it: collections are copied.
  Object _typed(Object value) => switch (value) {
    List() => [...value],
    Map() => {...value},
    _ => value,
  };

  /// The non-secret values as stored (what a form shows), by key.
  Future<Map<String, Object?>> storedValues(String installId) =>
      _stored(installId);

  /// Whether the secret of [key] has a value (for the form: filled or not).
  /// A stored secret over the length cap counts as none, as in a run.
  Future<bool> hasSecret(String installId, String key) async {
    final value = await _secrets.read(lyricsPluginSecretName(installId, key));
    return value != null && value.runes.length <= pluginConfigMaxText;
  }

  /// Removes the secret of every secret field of [schema]. Failures are
  /// logged (error type only) and do not stop the rest.
  /// Returns whether every delete succeeded.
  Future<bool> deleteSecretsOf(
    String installId,
    List<PluginConfigField> schema,
  ) async {
    var all = true;
    for (final field in schema.where(isSecretField)) {
      all &= await _deleteSecret(installId, field.key);
    }
    return all;
  }

  Future<bool> _deleteSecret(String installId, String key) async {
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
  /// its entry, a stored value whose field changed mode or format is dropped,
  /// and so is one that no longer fits its field.
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
        await _deleteSecret(installId, old.key);
      }
      if (now != null && !isSecretField(old) && isSecretField(now)) {
        final value = values[old.key];
        if (movesIntoSecret(old, now) && value is String && value.isNotEmpty) {
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
      if (!keepsStoredValue(before, after, key, values[key], values)) {
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
    return row == null ? {} : decodeStoredPluginConfig(row.configValues);
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
