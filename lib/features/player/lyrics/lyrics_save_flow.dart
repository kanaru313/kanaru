import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/lrc_sidecar_reader.dart';
import '../../../core/lyrics/online/lrc_sidecar_write_steps.dart';
import '../../../core/lyrics/online/lrc_sidecar_writer.dart';
import '../../../core/lyrics/online/online_lyrics_actions.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import 'lyrics_action_runner.dart';

/// "Save lyrics": asks where to save, writes the `.lrc` file of the song and
/// reports what happened.
///
/// It acts on the song and the record the [runner] captured when its menu
/// opened, so a track change during a dialog still saves that song. An
/// existing file is never touched before the user confirms replacing it by
/// name; the old file then goes to the trash. Every result gets its own
/// message, a partial one included.
Future<void> runLyricsSave(LyricsActionRunner runner) =>
    runner.guarded(() async {
      final target = runner.target;
      final path = target?.path;
      if (target == null || path == null) return;
      final navigator = runner.navigator;
      if (!navigator.mounted) return;
      final actions = runner.container.read(onlineLyricsActionsProvider);
      // One save of a song at a time: nothing opens while one runs.
      if (actions.isSaving(target.trackKey)) return;
      final origin = runner.origin;
      if (origin == null) {
        _report(runner, (result: null, kept: null));
        return;
      }
      final chosen = await showDialog<bool>(
        context: navigator.context,
        builder: (_) => const _SaveLyricsDialog(),
      );
      if (chosen != true || !navigator.mounted) return;
      var replaced = false;
      var outcome = await actions.save(target, origin);
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
        outcome = await actions.save(target, origin, replace: true);
      }
      if (!navigator.mounted) return;
      _report(runner, outcome, afterReplace: replaced);
    });

void _report(
  LyricsActionRunner runner,
  LyricsSaveOutcome outcome, {
  bool afterReplace = false,
}) {
  final l10n = runner.navigator.context.l10n;
  final (kind, title) = switch (outcome.result) {
    LrcWriteResult.written => (AppSnackBarKind.success, l10n.lyricsSaveWritten),
    LrcWriteResult.identical => (
      AppSnackBarKind.success,
      l10n.lyricsSaveIdentical,
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
  runner.messenger
    ?..clearSnackBars()
    ..showSnackBar(
      appSnackBar(
        kind: kind,
        title: title,
        details: switch (outcome.kept) {
          LyricsChoiceKept.tagPreferred => l10n.lyricsSaveKeptTag,
          LyricsChoiceKept.otherFile => l10n.lyricsSaveKeptOtherFile,
          null => null,
        },
      ),
    );
}

class _SaveLyricsDialog extends StatelessWidget {
  const _SaveLyricsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.lyricsSaveTitle),
      content: RadioGroup<String>(
        groupValue: 'lrc',
        onChanged: (_) {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'lrc',
              title: Text(l10n.lyricsSaveOptionLrc),
            ),
            RadioListTile<String>(
              value: 'tags',
              enabled: false,
              title: Text(l10n.lyricsSaveOptionTags),
              subtitle: Text(l10n.lyricsSaveOptionTagsSoon),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.lyricsSaveConfirm),
        ),
      ],
    );
  }
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
