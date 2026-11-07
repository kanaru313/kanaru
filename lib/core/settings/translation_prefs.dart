import '../lyrics_translation/translation_scope.dart'
    show TranslationScopePrecedence;
import '../lyrics_translation/translation_service.dart';

/// How a translated line is drawn next to the original.
enum LyricsTranslationDisplay {
  /// The translation under each original line.
  underLine,

  /// The translation instead of the original line.
  replace,
}

/// Options of the lyrics translation. Never holds a credential: keys live in
/// the secret store.
class TranslationPrefs {
  const TranslationPrefs({
    this.show = false,
    this.service,
    this.targetLanguage,
    this.display = LyricsTranslationDisplay.underLine,
    this.noticeAcknowledged = const {},
    this.allChosenAt,
    this.scopePrecedence = TranslationScopePrecedence.replaceAll,
  });

  /// Translated lines are shown (and fetched) for the playing song.
  final bool show;

  final TranslationServiceId? service;

  /// Language the lyrics are translated into, a code of
  /// `translationLanguages`; `null` follows the app's language.
  final String? targetLanguage;

  final LyricsTranslationDisplay display;

  /// Translate plugin ids the user accepted "lyrics will be sent to
  /// `<service>`" for. Switching to another service asks once more.
  final Set<TranslationServiceId> noticeAcknowledged;

  /// When (epoch ms) the user last picked the default service for all songs
  /// in the Now Playing menu; `null` if never. A song's own choice made later
  /// beats the default; Settings never sets it, so a default changed there
  /// never beats a song's choice.
  final int? allChosenAt;

  /// Whether a newer default replaces songs and queues set individually, or
  /// they keep their service.
  final TranslationScopePrecedence scopePrecedence;

  /// The stored [service] has not been accepted yet. Callers that decide
  /// about a request ask `needsNoticeFor` with the effective service.
  bool get needsNotice =>
      service == null || !noticeAcknowledged.contains(service);

  TranslationPrefs copyWith({
    bool? show,
    TranslationServiceId? service,
    LyricsTranslationDisplay? display,
    Set<TranslationServiceId>? noticeAcknowledged,
    int? allChosenAt,
    TranslationScopePrecedence? scopePrecedence,
  }) => TranslationPrefs(
    show: show ?? this.show,
    service: service ?? this.service,
    targetLanguage: targetLanguage,
    display: display ?? this.display,
    noticeAcknowledged: noticeAcknowledged ?? this.noticeAcknowledged,
    allChosenAt: allChosenAt ?? this.allChosenAt,
    scopePrecedence: scopePrecedence ?? this.scopePrecedence,
  );

  /// Returns a copy with [service] set to `null` and [show] set to `false`.
  ///
  /// Used by the sweep when the stored plugin is uninstalled.
  TranslationPrefs withoutService() => TranslationPrefs(
    show: false,
    service: null,
    targetLanguage: targetLanguage,
    display: display,
    noticeAcknowledged: noticeAcknowledged,
    allChosenAt: allChosenAt,
    scopePrecedence: scopePrecedence,
  );

  /// Separate from [copyWith] because `null` is a valid target here.
  TranslationPrefs withTargetLanguage(String? targetLanguage) =>
      TranslationPrefs(
        show: show,
        service: service,
        targetLanguage: targetLanguage,
        display: display,
        noticeAcknowledged: noticeAcknowledged,
        allChosenAt: allChosenAt,
        scopePrecedence: scopePrecedence,
      );

  @override
  bool operator ==(Object other) =>
      other is TranslationPrefs &&
      other.show == show &&
      other.service == service &&
      other.targetLanguage == targetLanguage &&
      other.display == display &&
      other.allChosenAt == allChosenAt &&
      other.scopePrecedence == scopePrecedence &&
      other.noticeAcknowledged.length == noticeAcknowledged.length &&
      other.noticeAcknowledged.containsAll(noticeAcknowledged);

  @override
  int get hashCode => Object.hash(
    show,
    service,
    targetLanguage,
    display,
    allChosenAt,
    scopePrecedence,
    Object.hashAllUnordered(noticeAcknowledged),
  );

  @override
  String toString() =>
      'TranslationPrefs(show: $show, service: ${service?.value}, '
      'targetLanguage: $targetLanguage, display: ${display.name}, '
      'noticeAcknowledged: ${noticeAcknowledged.map((s) => s.value).toList()}, '
      'allChosenAt: $allChosenAt, scopePrecedence: ${scopePrecedence.name})';
}
