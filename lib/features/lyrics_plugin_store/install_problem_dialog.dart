import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// A bordered box with a heading and one bullet per line.
class ProblemBox extends StatelessWidget {
  const ProblemBox({
    super.key,
    required this.title,
    required this.lines,
    this.error = true,
  });

  final String title;
  final List<String> lines;

  /// Draws the box and heading in the error colour.
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: error ? colors.error : colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: error ? colors.error : null,
              ),
            ),
            const SizedBox(height: 4),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('•  $line'),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Không cài được": [subject] says what was tried, [reasons] why it failed.
Future<void> showInstallProblemDialog(
  BuildContext context, {
  required String subject,
  required List<String> reasons,
}) {
  final l10n = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.lyricsStoreInstallFailedTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(subject),
            const SizedBox(height: 12),
            ProblemBox(title: l10n.lyricsStoreReasons, lines: reasons),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );
}

/// "Cần Kanaru mới hơn" for plugin [name].
Future<void> showNeedsNewerAppDialog(BuildContext context, String name) {
  final l10n = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.lyricsStoreNeedsNewerTitle),
      content: Text(l10n.lyricsStoreNeedsNewerBody(name)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );
}

/// "Gói không khớp danh sách": the package differs from its catalog entry.
/// [differences] are the lines to show. Completes with `true` when the user
/// chose to refresh the list and try again.
Future<bool> showCatalogMismatchDialog(
  BuildContext context, {
  required String subject,
  required List<String> differences,
}) async {
  final l10n = context.l10n;
  final theme = Theme.of(context);
  final retry = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.lyricsStoreMismatchTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(subject),
            const SizedBox(height: 12),
            ProblemBox(
              title: l10n.lyricsStoreMismatchDiffs,
              lines: differences,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.lyricsStoreMismatchHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.lyricsStoreMismatchRetry),
        ),
      ],
    ),
  );
  return retry ?? false;
}
