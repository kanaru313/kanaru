import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/lyrics_plugin_spec.dart';
import '../lyrics/plugins/package/plugin_config_field.dart';
import '../lyrics/plugins/store/plugin_config_values.dart';
import 'lyrics_translation_state.dart';

export '../lyrics/plugins/store/plugin_config_values.dart'
    show aiInstructionMaxRunes, combinedInstruction;

/// Keys of the standard fields every `ai-translate` plugin declares.
const aiModelKey = 'model';
const aiStyleKey = 'style';
const aiInstructionKey = 'customInstruction';

/// The three standard fields of an `ai-translate` plugin.
class TranslationAiTune {
  const TranslationAiTune({
    required this.model,
    required this.style,
    required this.instruction,
  });

  final PluginConfigField model;
  final PluginConfigField style;
  final PluginConfigField instruction;

  @override
  bool operator ==(Object other) =>
      other is TranslationAiTune &&
      other.model == model &&
      other.style == style &&
      other.instruction == instruction;

  @override
  int get hashCode => Object.hash(model, style, instruction);
}

/// The tune of a plugin of [kind] with form [config]; null for any kind but
/// `ai-translate`, or when a standard field is missing or of the wrong mode
/// (a record saved by an older version).
TranslationAiTune? aiTuneOf(PluginKind? kind, List<PluginConfigField> config) {
  if (kind != PluginKind.aiTranslate) return null;
  PluginConfigField? find(String key, PluginConfigMode mode) => config
      .where((f) => f.key == key && f.mode == mode)
      .cast<PluginConfigField?>()
      .firstOrNull;
  final model = find(aiModelKey, PluginConfigMode.select);
  final style = find(aiStyleKey, PluginConfigMode.select);
  final instruction = find(aiInstructionKey, PluginConfigMode.input);
  if (model == null || style == null || instruction == null) return null;
  return TranslationAiTune(
    model: model,
    style: style,
    instruction: instruction,
  );
}

/// What a run reads now for each standard field, from the stored values: the
/// model and style as [pluginEffectiveValue] (null when nothing fits), the
/// shared instruction as text ('' when none).
({Object? model, Object? style, String instruction}) aiTuneValues(
  TranslationAiTune tune,
  Map<String, Object?> stored,
) => (
  model: pluginEffectiveValue(pluginEffectiveField(tune.model, stored), stored),
  style: pluginEffectiveValue(pluginEffectiveField(tune.style, stored), stored),
  instruction: switch (pluginEffectiveValue(tune.instruction, stored)) {
    final String text => text,
    _ => '',
  },
);

/// `sha256:<hex>` of [combined]; null when it is empty. The snapshot keeps
/// this, never the text.
String? instructionHashOf(String combined) =>
    combined.isEmpty ? null : 'sha256:${sha256.convert(utf8.encode(combined))}';

/// The settings a job runs with, as saved with its result:
/// `{"model", "style", "instructionHash"}`.
String encodeAiSnapshot(
  TranslationAiTune tune,
  Map<String, Object?> stored,
  String? songNote,
) {
  final values = aiTuneValues(tune, stored);
  return jsonEncode({
    aiModelKey: values.model,
    aiStyleKey: values.style,
    'instructionHash': instructionHashOf(
      combinedInstruction(values.instruction, songNote),
    ),
  });
}

/// The map a snapshot holds; null for null, damaged or non-object text.
Map<String, Object?>? decodeAiSnapshot(String? json) {
  if (json == null) return null;
  try {
    final decoded = jsonDecode(json);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}

enum AiTuneKey { model, style, instruction }

/// One setting that differs from the snapshot of the version on screen.
/// [before] and [after] are the option values for `model` and `style`, the
/// instruction hashes for `instruction`. [removedOption]: [before] is no
/// longer one of the field's options.
class AiTuneChange {
  const AiTuneChange(
    this.key,
    this.before,
    this.after, {
    this.removedOption = false,
  });

  final AiTuneKey key;
  final Object? before;
  final Object? after;
  final bool removedOption;

  @override
  bool operator ==(Object other) =>
      other is AiTuneChange &&
      other.key == key &&
      other.before == before &&
      other.after == after &&
      other.removedOption == removedOption;

  @override
  int get hashCode => Object.hash(key, before, after, removedOption);

  @override
  String toString() =>
      'AiTuneChange($key, $before -> $after'
      '${removedOption ? ', removed' : ''})';
}

/// The settings now ([stored], [songNote]) that differ from [snapshot] (see
/// [decodeAiSnapshot]). Empty without a snapshot; a key the snapshot lacks is
/// skipped.
List<AiTuneChange> aiTuneChanges(
  TranslationAiTune tune,
  Map<String, Object?>? snapshot,
  Map<String, Object?> stored,
  String? songNote,
) {
  if (snapshot == null) return const [];
  final values = aiTuneValues(tune, stored);
  final changes = <AiTuneChange>[];
  void select(
    AiTuneKey key,
    String name,
    PluginConfigField field,
    Object? now,
  ) {
    if (!snapshot.containsKey(name) || snapshot[name] == now) return;
    final before = snapshot[name];
    final options = pluginEffectiveField(field, stored).options;
    changes.add(
      AiTuneChange(
        key,
        before,
        now,
        removedOption: before != null && !options.any((o) => o.value == before),
      ),
    );
  }

  select(AiTuneKey.model, aiModelKey, tune.model, values.model);
  select(AiTuneKey.style, aiStyleKey, tune.style, values.style);
  const hashKey = 'instructionHash';
  final hash = instructionHashOf(
    combinedInstruction(values.instruction, songNote),
  );
  if (snapshot.containsKey(hashKey) && snapshot[hashKey] != hash) {
    changes.add(AiTuneChange(AiTuneKey.instruction, snapshot[hashKey], hash));
  }
  return changes;
}

/// The differences a modal reports for the translation on screen: none unless
/// it is the selected plugin's own finished version (not another service's,
/// not while a retranslation runs) with a snapshot.
List<AiTuneChange> aiTuneChangesOf(
  TranslationAiTune tune,
  TranslationReady ready,
  Map<String, Object?> stored,
  String? songNote,
) => ready.fromOtherService || ready.refreshing
    ? const []
    : aiTuneChanges(
        tune,
        decodeAiSnapshot(ready.settingsJson),
        stored,
        songNote,
      );

/// The title of the option of [field] whose value is [value]; null when
/// there is no such option (or [value] is null). Pass the field from
/// [pluginEffectiveField] to find a model the user added.
String? aiOptionTitle(PluginConfigField field, Object? value) {
  if (value == null) return null;
  for (final option in field.options) {
    if (option.value == value) return option.title;
  }
  return null;
}
