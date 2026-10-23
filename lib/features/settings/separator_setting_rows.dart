import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'separator_dialog.dart';
import 'setting_row.dart';

/// "Split artists" and "Split genres": each row summarises its rules and
/// opens the dialog that edits them. Off without a library database, like
/// the other scan options.
class SeparatorSettingRows extends StatelessWidget {
  const SeparatorSettingRows({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SeparatorRow(SeparatorKind.artist),
        _SeparatorRow(SeparatorKind.genre),
      ],
    );
  }
}

class _SeparatorRow extends ConsumerWidget {
  const _SeparatorRow(this.kind);

  final SeparatorKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final split = ref.watch(
      settingsProvider.select((s) => splitPrefsOf(s.libraryScan, kind)),
    );
    final live = ref.watch(libraryDatabaseProvider) != null;
    final hint = switch (kind) {
      SeparatorKind.artist => l10n.separatorsArtistsHint,
      SeparatorKind.genre => l10n.separatorsGenresHint,
    };
    return SettingRow.single(
      title: switch (kind) {
        SeparatorKind.artist => l10n.separatorsArtistsTitle,
        SeparatorKind.genre => l10n.separatorsGenresTitle,
      },
      subtitle:
          '$hint\n'
          '${l10n.separatorsSummary(split.separators.length, split.keepWhole.length)}',
      control: FilledButton.tonal(
        style: settingButtonStyle(),
        onPressed: live ? () => showSeparatorDialog(context, kind) : null,
        child: Text(
          l10n.separatorsEditButton,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
