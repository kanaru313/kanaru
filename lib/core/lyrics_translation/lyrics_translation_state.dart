import 'package:flutter/foundation.dart';

import 'translation_failure.dart';
import 'translation_language.dart';
import 'translation_service.dart';

/// Which lyrics text and target language the Now Playing menu is about.
@immutable
class TranslationTargetInfo {
  const TranslationTargetInfo({
    required this.hash,
    required this.effective,
    required this.songOverride,
    required this.defaultTarget,
  });

  /// `lyricsContentHash` of the playing lyrics.
  final String hash;

  /// The language translated into: the song's override, else the default.
  final TranslationLanguage effective;

  /// The language picked for this song only, as a language code, or `null`.
  final String? songOverride;

  /// The language used when the song has no override.
  final TranslationLanguage defaultTarget;

  @override
  bool operator ==(Object other) =>
      other is TranslationTargetInfo &&
      other.hash == hash &&
      other.effective.code == effective.code &&
      other.songOverride == songOverride &&
      other.defaultTarget.code == defaultTarget.code;

  @override
  int get hashCode =>
      Object.hash(hash, effective.code, songOverride, defaultTarget.code);
}

/// What Now Playing shows for the translation of the playing lyrics.
/// Equality is by content, so a rebuild with the same content is no change.
@immutable
sealed class LyricsTranslationState {
  const LyricsTranslationState();

  List<Object?> get _props;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is LyricsTranslationState &&
      listEquals(other._props, _props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(_props));
}

/// No lyrics for the playing track, or the library database is unavailable.
class TranslationUnavailable extends LyricsTranslationState {
  const TranslationUnavailable();

  @override
  List<Object?> get _props => const [];
}

/// Translation is off: nothing is sent. [info] still serves the menu.
class TranslationOff extends LyricsTranslationState {
  const TranslationOff(this.info);

  final TranslationTargetInfo info;

  @override
  List<Object?> get _props => [info];
}

/// Waiting for the cache, the key, the debounce or a running job.
class TranslationLoading extends LyricsTranslationState {
  const TranslationLoading(this.info, this.service);

  final TranslationTargetInfo info;
  final LyricsTranslationService service;

  @override
  List<Object?> get _props => [info, service];
}

/// A translation to show. [lines] has one entry per lyrics line (`null`: no
/// translation to show). [service] is the one whose row this is; it differs
/// from the selected service when [fromOtherService].
class TranslationReady extends LyricsTranslationState {
  const TranslationReady(
    this.info,
    this.service,
    this.sourceLang,
    this.lines,
    this.fromOtherService,
  );

  final TranslationTargetInfo info;
  final LyricsTranslationService service;
  final String? sourceLang;
  final List<String?> lines;
  final bool fromOtherService;

  @override
  List<Object?> get _props => [
    info,
    service,
    sourceLang,
    fromOtherService,
    ...lines,
  ];
}

/// The lyrics are already in the target language; only a note is shown.
class TranslationSameLanguage extends LyricsTranslationState {
  const TranslationSameLanguage(this.info, this.service);

  final TranslationTargetInfo info;
  final LyricsTranslationService service;

  @override
  List<Object?> get _props => [info, service];
}

/// The request failed (or could not be made); remembered until Retry.
class TranslationFailed extends LyricsTranslationState {
  const TranslationFailed(this.info, this.service, this.kind);

  final TranslationTargetInfo info;
  final LyricsTranslationService service;
  final TranslationFailureKind kind;

  @override
  List<Object?> get _props => [info, service, kind];
}

/// Translation is on but the user has not accepted sending lyrics to
/// [service]; nothing was sent.
class TranslationNeedsNotice extends LyricsTranslationState {
  const TranslationNeedsNotice(this.info, this.service);

  final TranslationTargetInfo info;
  final LyricsTranslationService service;

  @override
  List<Object?> get _props => [info, service];
}
