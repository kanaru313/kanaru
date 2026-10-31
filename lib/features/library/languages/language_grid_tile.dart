import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/language_display_name.dart';
import '../../../shared/language_summaries.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import '../widgets/round_grid_tile.dart';
import 'language_avatar.dart';
import '../albums/album_grid.dart';

/// One language in a grid: round avatar, name, "N songs".
class LanguageGridTile extends StatelessWidget {
  const LanguageGridTile({
    super.key,
    required this.language,
    required this.onTap,
    this.onQueueAction,
  });

  final LanguageSummary language;
  final VoidCallback onTap;

  /// Picked from the menu of a right click or long press; no menu without it.
  final ValueChanged<QueueAction>? onQueueAction;

  @override
  Widget build(BuildContext context) => RoundGridTile(
    avatarBuilder: (size) =>
        LanguageAvatar(languageKey: language.key, size: size),
    title: languageSummaryName(context.l10n, language),
    subtitle: context.l10n.albumsSongCount(language.songCount),
    onTap: onTap,
    onQueueAction: onQueueAction,
  );
}

/// [languages] as a scrolling grid.
class LanguageGrid extends StatelessWidget {
  const LanguageGrid({
    super.key,
    required this.languages,
    required this.onTap,
    this.onQueueAction,
  });

  final List<LanguageSummary> languages;
  final void Function(LanguageSummary language) onTap;

  /// An action picked from the menu of a language; no menus without it.
  final void Function(LanguageSummary language, QueueAction action)?
  onQueueAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          albumGridPadding,
          0,
          albumGridPadding,
          24,
        ),
        gridDelegate: libraryGridDelegate(
          context,
          constraints.maxWidth - albumGridPadding * 2,
          tileHeight: roundGridTileHeight,
        ),
        itemCount: languages.length,
        itemBuilder: (context, i) => LanguageGridTile(
          language: languages[i],
          onTap: () => onTap(languages[i]),
          onQueueAction: onQueueAction == null
              ? null
              : (action) => onQueueAction!(languages[i], action),
        ),
      ),
    );
  }
}
