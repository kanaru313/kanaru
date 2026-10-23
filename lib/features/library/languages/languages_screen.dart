import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/icons/app_icons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../widgets/page_material.dart';

/// Placeholder of the Languages page until songs can be browsed by language.
class LanguagesScreen extends StatelessWidget {
  const LanguagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageMaterial(
      child: PageScaffold(
        title: l10n.navLanguages,
        body: EmptyState(
          icon: AppIcons.language,
          title: l10n.languagesComingSoonTitle,
          message: l10n.languagesComingSoonMessage,
        ),
      ),
    );
  }
}
