import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import 'show_hidden_provider.dart';

/// The eye button of the Folders pages: shows or hides the hidden folders and
/// files. The icon shows the current state; a tap switches it.
class HiddenToggleButton extends ConsumerWidget {
  const HiddenToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(showHiddenFoldersProvider);
    final l10n = context.l10n;
    return IconButton(
      tooltip: shown ? l10n.foldersHiddenHide : l10n.foldersHiddenShow,
      icon: Icon(shown ? AppIcons.showHidden : AppIcons.hideHidden),
      onPressed: ref.read(showHiddenFoldersProvider.notifier).toggle,
    );
  }
}
