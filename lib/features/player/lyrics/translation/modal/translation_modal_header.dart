import 'package:material_ui/material_ui.dart';

import '../../../../../l10n/l10n.dart';
import '../../../../../shared/icons/app_icons.dart';
import 'translation_modal_navigation.dart';

/// Header of the lyrics translation modal: its title, a settings button (`⚙`)
/// that closes the modal and Now Playing to open Playback › Translation, and
/// a close button (`✕`). It says nothing about the song: the modal opens on
/// the playing one.
class TranslationModalHeader extends StatelessWidget {
  const TranslationModalHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.lyricsTranslationModalTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.lyricsTranslationMenuSettings,
            icon: const Icon(AppIcons.settingsOutlined),
            onPressed: () => openTranslationSettings(context),
          ),
          IconButton(
            tooltip: l10n.contextModalClose,
            icon: const Icon(AppIcons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
