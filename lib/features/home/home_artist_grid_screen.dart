import 'package:material_ui/material_ui.dart';

import '../../core/database/library_database.dart' show ArtistCredit;
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import 'home_artist_card.dart';
import 'home_card_grid_screen.dart';
import 'home_paged_providers.dart';

/// Every artist played, newest listen first.
class HomeArtistGridScreen extends StatelessWidget {
  const HomeArtistGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HomeCardGridScreen<ArtistCredit>(
      title: l10n.homeRecentArtistsTitle,
      emptyText: l10n.homeRecentArtistsEmpty,
      emptyIcon: AppIcons.artistOutline,
      pages: homeRecentArtistsPagesProvider,
      cardBuilder: (artist) => HomeArtistCard(artist: artist),
    );
  }
}
