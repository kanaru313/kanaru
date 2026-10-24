import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/language_display_name.dart';
import '../../../shared/language_summaries.dart';
import '../../../shared/widgets/queue_actions_menu.dart';
import 'language_avatar.dart';

/// One language row: round avatar, name, "N songs".
class LanguageTile extends StatelessWidget {
  const LanguageTile({
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
  Widget build(BuildContext context) {
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      leading: LanguageAvatar(languageKey: language.key, size: 40),
      title: Text(
        languageSummaryName(context.l10n, language),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        context.l10n.albumsSongCount(language.songCount),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
    return QueueActionsRegion(onAction: onQueueAction, child: tile);
  }
}
