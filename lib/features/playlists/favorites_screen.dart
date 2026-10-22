import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/page_scaffold.dart';

/// The Favorites page: the songs the user liked. A placeholder until the
/// favorites playlist is listed.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageScaffold(
      title: l10n.navFavorites,
      body: EmptyState(
        icon: AppIcons.favoriteOutline,
        title: l10n.navFavorites,
        message: l10n.favoritesEmptyMessage,
      ),
    );
  }
}
