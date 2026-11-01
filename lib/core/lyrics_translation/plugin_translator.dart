import 'dart:math';

import '../lyrics/plugins/package/plugin_translate_spec.dart';
import '../lyrics/plugins/translate/plugin_translate_gate.dart'
    show TranslationSuperseded;
import '../lyrics/plugins/translate/plugin_translate_runner.dart';
import 'lyrics_translator.dart';
import 'translation_failure.dart';
import 'translation_language.dart';
import 'translation_lines.dart';
import 'translation_service.dart';
import 'translation_song_context.dart';

/// Most chunks one job may send to a plugin; a longer song is `tooLong`
/// (every chunk is a billed run).
const maxPluginChunksPerJob = 20;

/// Translates with an installed translate plugin. Built for one job, so it
/// knows the job's whole lyrics (sent as context with every chunk).
///
/// [allowed] is read at every chunk and send, never captured once: the user
/// may turn translation off, or switch service, while a long song runs.
/// [stillWanted] says whether the job is still the one on screen; a chunk
/// that is not wanted when its turn comes is dropped unsent
/// (`TranslationSuperseded`).
class PluginTranslator implements LyricsTranslator {
  PluginTranslator({
    required this.service,
    required this._runner,
    required this._spec,
    required this._jobLines,
    required this._allowed,
    required this._stillWanted,
  });

  @override
  final TranslationServiceId service;

  final PluginTranslateRunner _runner;
  final PluginTranslateSpec _spec;
  final List<String> _jobLines;
  final bool Function() _allowed;
  final bool Function() _stillWanted;

  PluginTranslateSong? _song;

  @override
  bool supports(TranslationLanguage language) =>
      _spec.languages.contains(language.code);

  @override
  TranslationChunkLimits get chunkLimits => TranslationChunkLimits(
    maxLines: min(_spec.maxLines, maxTranslatedLines),
    maxChars: min(_spec.maxChars, maxTranslatedChars),
    maxChunks: maxPluginChunksPerJob,
  );

  @override
  Future<TranslatedLines> translate(
    List<String> lines,
    TranslationLanguage target, {
    TranslationSongContext? song,
  }) async {
    // Built once: the lyrics of the job are the same for every chunk.
    final context = _song ??= PluginTranslateSong.fromLines(
      title: song?.title ?? '',
      artist: song?.artist ?? '',
      uniqueLines: _jobLines,
    );
    final List<PluginTranslatedLine> result;
    try {
      result = await _runner.translateChunk(
        service.value,
        lines,
        target.code,
        context,
        allowed: _allowed,
        stillWanted: _stillWanted,
      );
    } on TranslationException catch (e) {
      // Refused because the user turned translation off or switched service
      // meanwhile: not a failure to show, the job just ends.
      if (e.kind == TranslationFailureKind.blocked && !_allowed()) {
        throw const TranslationSuperseded();
      }
      rethrow;
    }
    return TranslatedLines(
      [for (final line in result) line.text],
      [for (final line in result) line.detected],
    );
  }
}
