import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/app_snack_bar.dart';
import 'release_date_chips.dart';
import 'song_info_groups.dart';
import 'wrap_anywhere.dart';

/// One "Label: value" line. The value wraps from the start of the line and,
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
    final label = TextSpan(
      text: '${field.label}: ',
      style: TextStyle(color: colors.onSurfaceVariant),
    );
    final text = Text.rich(
      TextSpan(
        children: [
          label,
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
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
    final line = value == null
        ? Semantics(
            label: '${field.label}: ${l10n.songInfoUnknown}',
            excludeSemantics: true,
            child: text,
          )
        : Tooltip(
            message: l10n.songInfoCopy,
            excludeFromSemantics: true,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(6),
              onTap: () => _copy(context, value),
              child: Semantics(
                button: true,
                label: '${field.label}: $value',
                hint: l10n.songInfoCopy,
                excludeSemantics: true,
                child: text,
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line,
          if (field.chips.isNotEmpty && value != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ReleaseDateChips(labels: field.chips),
            ),
        ],
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
