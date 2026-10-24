import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show AlbumSummary;
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'home_album_card.dart';
import 'home_card_grid_screen.dart';
import 'home_paged_providers.dart';

/// Every album played, newest listen first.
class HomeAlbumGridScreen extends StatelessWidget {
  const HomeAlbumGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HomeCardGridScreen<AlbumSummary>(
      title: l10n.homeRecentAlbumsTitle,
      emptyText: l10n.homeRecentAlbumsEmpty,
      emptyIcon: AppIcons.albumOutlined,
      pages: homeRecentAlbumsPagesProvider,
      cardBuilder: (album) => HomeAlbumCard(album: album),
    );
  }
}
