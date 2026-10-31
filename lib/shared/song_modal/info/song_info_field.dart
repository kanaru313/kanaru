import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/app_snack_bar.dart';
import 'release_date_chips.dart';
import 'song_info_groups.dart';
import 'wrap_anywhere.dart';

/// One "Label: value" row, full width. The value wraps from the start of the line and,
/// when long and unbroken (a path), anywhere. Tapping a known value copies
/// it as it is stored; an unknown one shows "Unknown" in italics and cannot
/// be copied.
class SongInfoFieldTile extends StatelessWidget {
  const SongInfoFieldTile({super.key, required this.field});

  final SongInfoField field;

  Future<void> _copy(BuildContext context, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: value));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          kind: AppSnackBarKind.success,
          title: l10n.songInfoCopied(value),
          duration: const Duration(milliseconds: 2000),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final value = field.value;
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${field.label}: ',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          value == null
              ? TextSpan(
                  text: l10n.songInfoUnknown,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : TextSpan(
                  text: wrapAnywhere(value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
    // The chips of a release date continue on the same line, and wrap under
    // it only when the row is narrow.
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          text,
          if (field.chips.isNotEmpty && value != null)
            ReleaseDateChips(labels: field.chips),
        ],
      ),
    );
    if (value == null) {
      return Semantics(
        label: '${field.label}: ${l10n.songInfoUnknown}',
        excludeSemantics: true,
        child: content,
      );
    }
    // The whole row, edge to edge, is the hover and tap target.
    return Tooltip(
      message: l10n.songInfoCopy,
      excludeFromSemantics: true,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () => _copy(context, value),
        child: Semantics(
          button: true,
          label: '${field.label}: $value',
          hint: l10n.songInfoCopy,
          excludeSemantics: true,
          child: content,
        ),
      ),
    );
  }
}

/// A group heading: Tags, Audio, File.
class SongInfoGroupHeading extends StatelessWidget {
  const SongInfoGroupHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
