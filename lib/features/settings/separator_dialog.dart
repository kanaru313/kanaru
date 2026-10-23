import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import 'separator_entry_tab.dart';
import 'settings_confirm_dialog.dart';

/// Which tags a separator dialog edits.
enum SeparatorKind { artist, genre }

/// The split rules of [kind] in [scan].
SplitPrefs splitPrefsOf(LibraryScanPrefs scan, SeparatorKind kind) =>
    switch (kind) {
      SeparatorKind.artist => scan.artistSplit,
      SeparatorKind.genre => scan.genreSplit,
    };

/// Opens the dialog that edits how [kind] tags are split.
Future<void> showSeparatorDialog(BuildContext context, SeparatorKind kind) =>
    showDialog<void>(
      context: context,
      builder: (context) => SeparatorDialog(kind: kind),
    );

/// Two tabs: the separators, and the names that are never split. Every
/// change is saved at once; the settings notifier takes care of the rest
/// (the library updates itself in the background when artist rules change).
class SeparatorDialog extends ConsumerStatefulWidget {
  const SeparatorDialog({super.key, required this.kind});

  final SeparatorKind kind;

  @override
  ConsumerState<SeparatorDialog> createState() => _SeparatorDialogState();
}

class _SeparatorDialogState extends ConsumerState<SeparatorDialog>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Saves [change] applied to the rules as they are now, not as they were
  /// when this dialog last built.
  void _write(SplitPrefs Function(SplitPrefs current) change) {
    final settings = ref.read(settingsProvider.notifier);
    final scan = ref.read(settingsProvider).libraryScan;
    final next = change(splitPrefsOf(scan, widget.kind));
    settings.setLibraryScan(switch (widget.kind) {
      SeparatorKind.artist => scan.copyWith(artistSplit: next),
      SeparatorKind.genre => scan.copyWith(genreSplit: next),
    });
  }

  Future<void> _reset() async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.separatorsResetConfirmTitle,
      body: l10n.separatorsResetConfirmBody,
      confirmLabel: l10n.separatorsResetConfirm,
    );
    if (!confirmed || !mounted) return;
    _write(
      (_) => switch (widget.kind) {
        SeparatorKind.artist => defaultArtistSplit,
        SeparatorKind.genre => defaultGenreSplit,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = widget.kind;
    final split = ref.watch(
      settingsProvider.select((s) => splitPrefsOf(s.libraryScan, kind)),
    );
    final isDefault =
        split ==
        switch (kind) {
          SeparatorKind.artist => defaultArtistSplit,
          SeparatorKind.genre => defaultGenreSplit,
        };
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (kind) {
                SeparatorKind.artist => l10n.separatorsArtistsTitle,
                SeparatorKind.genre => l10n.separatorsGenresTitle,
              }, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(
                    text: l10n.separatorsTabSeparators(split.separators.length),
                  ),
                  Tab(
                    text: l10n.separatorsTabKeepWhole(split.keepWhole.length),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Both tabs stay built, so a half-typed entry survives a switch;
              // the one not shown is off-stage.
              IndexedStack(
                index: _tabs.index,
                children: [
                  SeparatorEntryTab(
                    entries: split.separators,
                    fieldLabel: l10n.separatorsAddSeparatorLabel,
                    helpText: l10n.separatorsSeparatorHelp,
                    emptyText: l10n.separatorsEmptySeparators,
                    onAdd: (entry) => _write(
                      (c) => c.copyWith(separators: [...c.separators, entry]),
                    ),
                    onRemove: (entry) => _write(
                      (c) => c.copyWith(
                        separators: [...c.separators]..remove(entry),
                      ),
                    ),
                  ),
                  SeparatorEntryTab(
                    entries: split.keepWhole,
                    fieldLabel: l10n.separatorsAddKeepLabel,
                    helpText: switch (kind) {
                      SeparatorKind.artist => l10n.separatorsKeepHelpArtist,
                      SeparatorKind.genre => l10n.separatorsKeepHelpGenre,
                    },
                    emptyText: l10n.separatorsEmptyList,
                    onAdd: (entry) => _write(
                      (c) => c.copyWith(keepWhole: [...c.keepWhole, entry]),
                    ),
                    onRemove: (entry) => _write(
                      (c) => c.copyWith(
                        keepWhole: [...c.keepWhole]..remove(entry),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: isDefault ? null : _reset,
                    child: Text(l10n.separatorsReset),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.separatorsClose),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
