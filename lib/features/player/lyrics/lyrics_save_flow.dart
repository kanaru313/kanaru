import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lrc_sidecar_reader.dart';
import '../../../core/lyrics/online/lrc_sidecar_write_steps.dart';
import '../../../core/lyrics/online/lrc_sidecar_writer.dart';
import '../../../core/lyrics/online/online_lyrics_actions.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import 'lyrics_action_runner.dart';

/// Where "Save lyrics to" can write. The tags are listed in the modal but
/// cannot be chosen yet, so `lrc` is the only target.
enum LyricsSaveTarget { lrc }

/// Saves the lyrics on screen to every chosen target and reports what
/// happened.
///
/// It acts on the song and the record the [runner] captured when the modal
/// opened, so a track change meanwhile still saves that song. Online lyrics
/// are written from their stored text, lyrics from the song's tags from the
/// tags. An existing file is never touched before the user confirms replacing
/// it by name; the old file then goes to the trash. Every result gets its own
/// message, a partial one included; a save refused because another save of
/// the song runs says nothing.
Future<void> runLyricsSaveTargets(
  LyricsActionRunner runner,
  Set<LyricsSaveTarget> targets,
) => runner.guarded(() async {
  final target = runner.target;
  final path = target?.path;
  if (target == null || path == null || targets.isEmpty) return;
  final navigator = runner.navigator;
  if (!navigator.mounted) return;
  final actions = runner.container.read(onlineLyricsActionsProvider);
  final origin = runner.origin;
  final fromTags = origin == null && runner.isTagLyrics;
  if (origin == null && !fromTags) {
    _report(runner, (result: null, kept: null));
    return;
  }

  // A second save of the song while one runs answers `null`: say nothing.
  Future<LyricsSaveOutcome?> save({required bool replace}) async {
    if (actions.isSaving(target.trackKey)) return null;
    return origin != null
        ? actions.save(target, origin, replace: replace)
        : actions.saveLocalAsLrc(target, replace: replace);
  }

  var replaced = false;
  var outcome = await save(replace: false);
  if (outcome == null) return;
  if (outcome.result == LrcWriteResult.exists) {
    final names = await existingLrcSidecars(path);
    if (!navigator.mounted) return;
    final replace = await showDialog<bool>(
      context: navigator.context,
      builder: (_) => _ReplaceLyricsDialog(
        files: names.isEmpty
            ? [lrcCandidates(path).first.split('/').last]
            : names,
        title: target.query.title ?? path.split('/').last,
      ),
    );
    if (replace != true) return;
    replaced = true;
    outcome = await save(replace: true);
    if (outcome == null) return;
  }
  String? fileName;
  if (outcome.result == LrcWriteResult.identical) {
    final names = await existingLrcSidecars(path);
    fileName = names.isEmpty
        ? lrcCandidates(path).first.split('/').last
        : names.first;
  }
  if (!navigator.mounted) return;
  _report(
    runner,
    outcome,
    afterReplace: replaced,
    fileName: fileName,
    fromTags: origin == null,
  );
});

void _report(
  LyricsActionRunner runner,
  LyricsSaveOutcome outcome, {
  bool afterReplace = false,
  String? fileName,
  bool fromTags = false,
}) {
  final l10n = runner.navigator.context.l10n;
  final (kind, title) = switch (outcome.result) {
    LrcWriteResult.written => (AppSnackBarKind.success, l10n.lyricsSaveWritten),
    LrcWriteResult.identical => (
      AppSnackBarKind.success,
      l10n.lyricsSaveAlready(fileName ?? ''),
    ),
    LrcWriteResult.outsideLibrary => (
      AppSnackBarKind.error,
      l10n.lyricsSaveOutsideLibrary,
    ),
    // A file appeared while replacing: nothing was replaced.
    LrcWriteResult.exists when afterReplace => (
      AppSnackBarKind.error,
      l10n.lyricsSaveReplaceRaced,
    ),
    LrcWriteResult.failed ||
    LrcWriteResult.exists => (AppSnackBarKind.error, l10n.lyricsSaveFailed),
    LrcWriteResult.trashTimedOut => (
      AppSnackBarKind.error,
      l10n.lyricsSaveTrashTimedOut,
    ),
    LrcWriteResult.trashFailed => (
      AppSnackBarKind.error,
      l10n.lyricsSaveTrashFailed,
    ),
    LrcWriteResult.trashedNotWritten => (
      AppSnackBarKind.error,
      l10n.lyricsSaveTrashedNotWritten,
    ),
    LrcWriteResult.nothingToWrite ||
    null => (AppSnackBarKind.error, l10n.lyricsSaveNothing),
  };
  runner.messenger?.showAppSnackBar(
    kind,
    title,
    details: switch (outcome.kept) {
      LyricsChoiceKept.tagPreferred =>
        fromTags ? l10n.lyricsSaveKeptTagSame : l10n.lyricsSaveKeptTag,
      LyricsChoiceKept.otherFile => l10n.lyricsSaveKeptOtherFile,
      null => null,
    },
  );
}

class _ReplaceLyricsDialog extends StatelessWidget {
  const _ReplaceLyricsDialog({required this.files, required this.title});

  /// Every file that goes to the trash.
  final List<String> files;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final names = files.length == 2
        ? l10n.lyricsReplaceFilesJoin(files[0], files[1])
        : files.join(', ');
    return AlertDialog(
      title: Text(l10n.lyricsReplaceTitle(names, title)),
      content: Text(l10n.lyricsReplaceBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.lyricsReplaceAction),
        ),
      ],
    );
  }
}
