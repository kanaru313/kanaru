import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_plugin_record.dart';
import 'package:kanaru/core/lyrics/plugins/lyrics_sources_provider.dart';
import 'package:kanaru/core/lyrics/plugins/package/plugin_manifest.dart'
    show PluginConfigField;
import 'package:kanaru/core/lyrics/plugins/package/plugin_translate_spec.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_gate.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner.dart';
import 'package:kanaru/core/lyrics/plugins/translate/plugin_translate_runner_provider.dart';
import 'package:kanaru/core/lyrics_translation/translation_failure.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';

const testTranslatePluginId = 'plugin-abc123def456';
final testTranslatePlugin = TranslationServiceId.tryParse(
  testTranslatePluginId,
)!;

/// Riverpod overrides for translate plugins in tests.
List<Override> translatePluginOverrides({
  List<LyricsPluginRecord>? records,
  PluginTranslateRunner? runner,
}) {
  final list =
      records ??
      [translateRecord(testTranslatePluginId, name: 'Test Translate')];
  return [
    translatePluginRecordsProvider.overrideWithValue(AsyncValue.data(list)),
    lyricsPluginRecordsProvider.overrideWithValue(list),
    if (runner != null) pluginTranslateRunnerProvider.overrideWithValue(runner),
  ];
}

/// A live translate plugin record.
LyricsPluginRecord translateRecord(
  String id, {
  int updatedAt = 5,
  bool removed = false,
  PluginKind kind = PluginKind.translate,
  String? name,
  List<String> hosts = const ['api.example.com'],
}) => LyricsPluginRecord(
  kind: kind,
  installId: id,
  name: name ?? 'Plugin $id',
  version: 1,
  apiVersion: 1,
  hosts: hosts,
  config: const [],
  packageDir: '$id/v1-1',
  sourceKind: LyricsPluginSourceKind.file,
  sourceName: 'x.zip',
  installedAt: 5,
  updatedAt: updatedAt,
  removedAt: removed ? 1 : null,
);

/// Stands in for the runner of translate plugins: goes through the real
/// gate, asks `allowed` like the real one and answers from a script.
class FakePluginRunner implements PluginTranslateRunner {
  FakePluginRunner({
    PluginTranslateSpec? spec_,
    PluginTranslateGate? gate,
    this.detected = 'ja',
  }) : spec_ =
           spec_ ??
           PluginTranslateSpec(
             languages: [for (final l in translationLanguages) l.code],
             maxLines: 50,
             maxChars: 4000,
           ),
       gate = gate ?? PluginTranslateGate();

  final PluginTranslateSpec spec_;
  final PluginTranslateGate gate;

  /// Language reported for every line; `null` reports none.
  String? detected;

  /// The lines of each chunk that went out, in order.
  final calls = <List<String>>[];

  /// The song of each chunk that went out.
  final songs = <PluginTranslateSong?>[];

  /// The target code of each chunk that went out.
  final targets = <String>[];

  /// Chunk index (from 0) to the error that chunk throws.
  final errors = <int, Object>{};

  /// Waited for before answering a chunk.
  Completer<void>? hold;

  /// Runs once when a chunk is sent (after it passed the gate).
  void Function(int index)? onSend;

  /// What a line becomes; `null` models a plugin leaving it unchanged.
  String Function(String line) transform = (line) => 'tr:$line';

  @override
  Future<PluginTranslateInfo> spec(String installId) async => (
    spec: spec_,
    hosts: const ['api.example.com'],
    config: <PluginConfigField>[],
  );

  @override
  Future<List<PluginTranslatedLine>> translateChunk(
    String installId,
    List<String> lines,
    String to,
    PluginTranslateSong? song, {
    required bool Function() allowed,
    bool Function()? stillWanted,
  }) => gate.run(stillWanted ?? () => true, () async {
    if (!allowed()) {
      throw const TranslationException(TranslationFailureKind.blocked);
    }
    final index = calls.length;
    calls.add(List.of(lines));
    targets.add(to);
    songs.add(song);
    onSend?.call(index);
    await hold?.future;
    final error = errors[index];
    if (error != null) throw error;
    return [
      for (final line in lines) (text: transform(line), detected: detected),
    ];
  });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
