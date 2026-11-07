import 'package:flutter/foundation.dart';

import 'translation_failure.dart';
import 'translation_language.dart';
import 'translation_scope.dart';
import 'translation_service.dart';

/// Which lyrics text and target language the Now Playing menu is about.
@immutable
class TranslationTargetInfo {
  const TranslationTargetInfo({
    required this.hash,
    required this.effective,
    required this.songOverride,
    required this.defaultTarget,
    this.choice,
  });

  /// `lyricsContentHash` of the playing lyrics.
  final String hash;

  /// The language translated into: the song's override, else the default.
  final TranslationLanguage effective;

  /// The language picked for this song only, as a language code, or `null`.
  final String? songOverride;

  /// The language used when the song has no override.
  final TranslationLanguage defaultTarget;

  /// The service choice for this song (which tier decided, and the default),
  /// or `null` when it is not known yet or the state has no use for it.
  final TranslationChoice? choice;

  @override
  bool operator ==(Object other) =>
      other is TranslationTargetInfo &&
      other.hash == hash &&
      other.effective.code == effective.code &&
      other.songOverride == songOverride &&
      other.defaultTarget.code == defaultTarget.code &&
      other.choice == choice;

  @override
  int get hashCode => Object.hash(
    hash,
    effective.code,
    songOverride,
    defaultTarget.code,
    choice,
  );
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
  final TranslationServiceId service;

  @override
  List<Object?> get _props => [info, service];
}

/// A translation to show. [lines] has one entry per lyrics line (`null`: no
/// translation to show). [service] is the one whose row this is; it differs
/// from the selected service when [fromOtherService].
///
/// [refreshing]: a job is translating again while this older version stays
/// shown. [retranslateFailure]: that job failed; the version shown is kept and
/// the failure is for the selected service (which may not be [service]).
class TranslationReady extends LyricsTranslationState {
  const TranslationReady(
    this.info,
    this.service,
    this.sourceLang,
    this.lines,
    this.fromOtherService, {
    this.refreshing = false,
    this.retranslateFailure,
    this.settingsJson,
  });

  final TranslationTargetInfo info;
  final TranslationServiceId service;
  final String? sourceLang;
  final List<String?> lines;
  final bool fromOtherService;
  final bool refreshing;
  final TranslationFailureKind? retranslateFailure;

  /// The AI settings this version was made with, or null (see
  /// `CachedTranslation.settingsJson`).
  final String? settingsJson;

  @override
  List<Object?> get _props => [
    info,
    service,
    sourceLang,
    fromOtherService,
    refreshing,
    retranslateFailure,
    settingsJson,
    ...lines,
  ];
}

/// The lyrics are already in the target language; only a note is shown.
class TranslationSameLanguage extends LyricsTranslationState {
  const TranslationSameLanguage(
    this.info,
    this.service, {
    this.fromOtherService = false,
    this.refreshing = false,
    this.retranslateFailure,
  });

  final TranslationTargetInfo info;

  /// The service whose verdict is shown.
  final TranslationServiceId service;

  /// Whether [service] is not the selected one (a fallback, no request made).
  final bool fromOtherService;

  /// A retranslate is running while this note stays.
  final bool refreshing;

  /// Why the last retranslate failed, while this note stays.
  final TranslationFailureKind? retranslateFailure;

  @override
  List<Object?> get _props => [
    info,
    service,
    fromOtherService,
    refreshing,
    retranslateFailure,
  ];
}

/// The request failed (or could not be made); remembered until Retry.
class TranslationFailed extends LyricsTranslationState {
  const TranslationFailed(this.info, this.service, this.kind);

  final TranslationTargetInfo info;
  final TranslationServiceId service;
  final TranslationFailureKind kind;

  @override
  List<Object?> get _props => [info, service, kind];
}

/// Translation is on but the user has not accepted sending lyrics to
/// [service]; nothing was sent.
class TranslationNeedsNotice extends LyricsTranslationState {
  const TranslationNeedsNotice(this.info, this.service);

  final TranslationTargetInfo info;
  final TranslationServiceId service;

  @override
  List<Object?> get _props => [info, service];
}
