import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics_translation/translation_scope.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/selection_picker.dart';
import 'setting_row.dart';

/// "When changing the service for all songs": whether a newer default
/// service replaces songs and the queue set individually, or they keep their
/// service. The value button opens a [showSelectionPicker]; a pick is saved
/// at once and changes no song's or queue's own choice.
class TranslationScopePrecedenceSettingRow extends ConsumerWidget {
  const TranslationScopePrecedenceSettingRow({super.key});

  String _name(AppLocalizations l10n, TranslationScopePrecedence value) =>
      switch (value) {
        TranslationScopePrecedence.replaceAll =>
          l10n.settingsTranslationScopeReplaceAll,
        TranslationScopePrecedence.keepCustom =>
          l10n.settingsTranslationScopeKeepCustom,
      };

  String _hint(AppLocalizations l10n, TranslationScopePrecedence value) =>
      switch (value) {
        TranslationScopePrecedence.replaceAll =>
          l10n.settingsTranslationScopeReplaceAllHint,
        TranslationScopePrecedence.keepCustom =>
          l10n.settingsTranslationScopeKeepCustomHint,
      };

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = ref.read(settingsProvider).translation.scopePrecedence;
    final picked = await showSelectionPicker<TranslationScopePrecedence>(
      context,
      title: l10n.settingsTranslationScopePrecedence,
      items: [
        for (final value in TranslationScopePrecedence.values)
          SelectionPickerItem(
            value: value,
            name: _name(l10n, value),
            description: _hint(l10n, value),
          ),
      ],
      selected: current,
    );
    if (picked == null || picked == current) return;
    // Read again: the settings may have changed while the picker was open.
    final prefs = ref.read(settingsProvider).translation;
    ref
        .read(settingsProvider.notifier)
        .setTranslation(prefs.copyWith(scopePrecedence: picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final value = ref.watch(
      settingsProvider.select((s) => s.translation.scopePrecedence),
    );
    return SettingRow.single(
      title: l10n.settingsTranslationScopePrecedence,
      control: OutlinedButton(
        onPressed: () => unawaited(_open(context, ref)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _name(l10n, value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(AppIcons.expandMore, size: 18, color: colors.outline),
          ],
        ),
      ),
    );
  }
}
