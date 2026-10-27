import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// (the caller then starts one after the debounce). [deeplKey] is the stored
/// key when [service] is DeepL, else `null`.
({LyricsTranslationState state, bool needsRequest}) deriveTranslation({
  required TranslationTargetInfo info,
  required LyricsTranslationService service,
  required Lyrics lyrics,
  required List<CachedTranslation> rows,
  required TranslationJobStatus? job,
  required AsyncValue<String?>? deeplKey,
}) {
  final target = info.effective;
  final picked = pickCached([
    for (final row in rows)
      if (isUsableTranslation(row, target)) row,
  ], service);
  TranslationLoading loading() => TranslationLoading(info, service);
  LyricsTranslationState fromRow(CachedTranslation row, bool other) =>
      isSameLanguage(row.sourceLang, target)
      ? TranslationSameLanguage(info, row.service)
      : TranslationReady(
          info,
          row.service,
          row.sourceLang,
          _linesOf(row, lyrics),
          other,
        );

  if (job != null && job.isRunning) {
    return (state: loading(), needsRequest: false);
  }
  final current = picked.current;
  final saved = job?.saved;
  if (saved != null &&
      (current == null || linesFingerprint(current.lines) != saved)) {
    // The job saved a row the stream has not shown yet; what is shown now is
    // the row it replaced, or the other service's. If the row was deleted
    // since, the request is made again.
    return (state: loading(), needsRequest: current == null);
  }
  if (current != null) {
    return (state: fromRow(current, false), needsRequest: false);
  }
  final failure = job?.failure;
  if (failure != null) {
    return (
      state: TranslationFailed(info, service, failure),
      needsRequest: false,
    );
  }
  final other = picked.other;
  if (other != null) return (state: fromRow(other, true), needsRequest: false);
  if (deeplKey != null) {
    if (deeplKey.isLoading) return (state: loading(), needsRequest: false);
    final kind = deeplKey.hasError
        ? failureKindOfSecretError(deeplKey.error!)
        : deeplKey.value == null
        ? TranslationFailureKind.noKey
        : null;
    if (kind != null) {
      return (
        state: TranslationFailed(info, service, kind),
        needsRequest: false,
      );
    }
  }
  return (state: loading(), needsRequest: true);
}
