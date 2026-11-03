import 'package:material_ui/material_ui.dart';

import '../../core/m3u/m3u_import.dart';
import '../../core/m3u/m3u_parse.dart' show m3uMaxPathLines;
import '../../core/m3u/m3u_text.dart';
import '../../l10n/l10n.dart';

/// Unresolved lines listed by name; the rest is counted.
const m3uReportMaxLines = 100;

/// Characters shown of one unresolved line.
const m3uReportMaxLineLength = 300;

/// Shows what an M3U import did: how many songs were added, how many are not
/// in the library yet, and the lines that were not found. [added] is 0 when
/// nothing was imported.
Future<void> showM3uImportReport(
  BuildContext context, {
  required M3uImportResult result,
  required int added,
  required int notInLibrary,
}) {
  final l10n = context.l10n;
  final lines = result.unresolved;
  final shown = lines.take(m3uReportMaxLines).toList();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.playlistM3uImportReportTitle),
      content: SizedBox(
        width: 560,
        child: SelectionArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                added == 0
                    ? l10n.playlistM3uImportNothingFound
                    : l10n.playlistM3uImportReportSummary(added, result.total),
              ),
              if (notInLibrary > 0)
                Text(l10n.playlistM3uImportReportNotInLibrary(notInLibrary)),
              if (lines.isNotEmpty)
                Text(l10n.playlistM3uImportReportUnresolved(lines.length)),
              if (result.truncated)
                Text(l10n.playlistM3uImportReportTruncated(m3uMaxPathLines)),
              if (shown.isNotEmpty) const SizedBox(height: 12),
              for (final line in shown)
                Text(
                  l10n.playlistM3uImportReportLine(
                    line.line,
                    m3uReportLineText(line.text),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (lines.length > shown.length)
                Text(
                  l10n.playlistM3uImportReportMore(lines.length - shown.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );
}

/// [text] cut to [m3uReportMaxLineLength] characters (whole graphemes), with
/// [m3uUnsafeTextChars] as spaces.
String m3uReportLineText(String text) {
  final clean = text.replaceAll(m3uUnsafeTextChars, ' ').characters;
  return clean.length <= m3uReportMaxLineLength
      ? clean.string
      : '${clean.take(m3uReportMaxLineLength)}…';
}
