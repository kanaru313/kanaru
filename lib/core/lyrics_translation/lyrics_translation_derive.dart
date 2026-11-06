import '../lyrics/lyrics.dart';
import '../secrets/secret_store.dart';
import 'lyrics_translation_state.dart';
import 'translation_cache.dart';
import 'translation_failure.dart';
import 'translation_job_work.dart';
import 'translation_jobs.dart';
import 'translation_language.dart';
import 'translation_lines.dart';
import 'translation_service.dart';

/// The failure a secret store error stands for: a locked keyring is
/// something the user can fix, everything else is "not available".
TranslationFailureKind failureKindOfSecretError(Object error) =>
    error is SecretStoreException && error.kind == SecretStoreFailure.locked
    ? TranslationFailureKind.keyStoreLocked
    : TranslationFailureKind.keyStoreUnavailable;

/// A saved row is a result when it has lines or the song was judged to be in
/// the target language already. An empty row of another language is a failed
/// translation that must not be shown as a result.
bool isUsableTranslation(CachedTranslation row, TranslationLanguage target) =>
    row.lines.isNotEmpty || isSameLanguage(row.sourceLang, target);

// Aligning is linear in the lyrics; remember it per row object and lyrics.
final _alignedLines = Expando<({Lyrics lyrics, List<String?> lines})>();

List<String?> _linesOf(CachedTranslation row, Lyrics lyrics) {
  final memo = _alignedLines[row];
  if (memo != null && identical(memo.lyrics, lyrics)) return memo.lines;
  final lines = List<String?>.unmodifiable(
    alignTranslations(lyrics.lines, row.lines),
  );
  _alignedLines[row] = (lyrics: lyrics, lines: lines);
  return lines;
}

/// What to show for the inputs, and whether a request must be made for it
/// (the caller then starts one after the debounce).
({LyricsTranslationState state, bool needsRequest}) deriveTranslation({
  required TranslationTargetInfo info,
  required TranslationServiceId service,
  Set<TranslationServiceId> knownPlugins = const {},
  required Lyrics lyrics,
  required List<CachedTranslation> rows,
  required TranslationJobStatus? job,
}) {
  final target = info.effective;
  final picked = pickCached(
    [
      for (final row in rows)
        if (isUsableTranslation(row, target)) row,
    ],
    service,
    knownPlugins: knownPlugins,
    target: target,
  );
  TranslationLoading loading() => TranslationLoading(info, service);
  LyricsTranslationState fromRow(
    CachedTranslation row,
    bool other, {
    bool refreshing = false,
    TranslationFailureKind? failure,
  }) => isSameLanguage(row.sourceLang, target)
      ? TranslationSameLanguage(info, row.service)
      : TranslationReady(
          info,
          row.service,
          row.sourceLang,
          _linesOf(row, lyrics),
          other,
          refreshing: refreshing,
          retranslateFailure: failure,
          settingsJson: row.settingsJson,
        );

  final current = picked.current;
  final otherRow = picked.other;
  // The version on screen: the selected service's, else another service's.
  final shown = current ?? otherRow;
  LyricsTranslationState keepShown() => shown == null
      ? loading()
      : fromRow(shown, current == null, refreshing: true);

  if (job != null && job.isRunning) {
    return (state: keepShown(), needsRequest: false);
  }
  final saved = job?.saved;
  if (saved != null &&
      (current == null ||
          translationFingerprint(current.lines, current.settingsJson) !=
              saved)) {
    // The job saved a row the stream has not shown yet; what is shown now is
    // the row it replaced, or the other service's. If the row was deleted
    // since, the request is made again.
    return (state: keepShown(), needsRequest: current == null);
  }
  final failure = job?.failure;
  if (shown != null) {
    return (
      state: fromRow(shown, current == null, failure: failure),
      needsRequest: false,
    );
  }
  if (failure != null) {
    return (
      state: TranslationFailed(info, service, failure),
      needsRequest: false,
    );
  }
  return (state: loading(), needsRequest: true);
}
