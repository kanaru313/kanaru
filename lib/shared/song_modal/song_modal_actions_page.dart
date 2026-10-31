import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/library_startup.dart';
import '../../core/database/track_links_provider.dart';
import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_route.dart';
import '../widgets/queue_actions_menu.dart';
import 'song_modal_data.dart';
import 'song_modal_actions.dart';
import 'song_modal_advanced_page.dart';
import 'info/song_info_page.dart';
import 'song_modal_header.dart';
import 'song_modal_session.dart';

/// The first page of the song modal: header, the links and song actions, and
/// the queue buttons in the footer. Favorite and links load while it is
/// open; until then their rows are greyed out.
ContextModalPage songModalActionsPage(SongModalSession session) {
  return ContextModalPage(
    key: 'song-actions',
    headerBuilder: (context, nav) => SongModalHeader(
      song: session.song,
      onTap: () => nav.push(songInfoPage(session)),
    ),
    bodyBuilder: (context, nav) => [
      Consumer(
        builder: (context, ref, _) {
          final hasLibrary = ref.watch(libraryDatabaseProvider) != null;
          final data = SongModalData(
            song: session.song,
            links: ref
                .watch(trackModalLinksProvider(session.song.id))
                .asData
                ?.value,
            isFavorite: ref
                .watch(songModalIsFavoriteProvider(session.song.path))
                .asData
                ?.value,
            hasLibrary: hasLibrary,
            canFindLyrics: session.lyricsTarget != null,
            showAlbum: session.showAlbum,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: contextModalSections(
              nav,
              songModalSections(
                context.l10n,
                data,
                session.handlers(
                  openAdvanced: (nav) => nav.push(
                    songModalAdvancedPage(session, hasLibrary: hasLibrary),
                  ),
                ),
                extra: session.extraActions,
              ),
            ),
          );
        },
      ),
    ],
    footerBuilder: (context, nav) => _QueueFooter(session: session, nav: nav),
  );
}

/// Play next and Add to queue: each closes the modal, then hands its action
/// to the screen.
class _QueueFooter extends StatelessWidget {
  const _QueueFooter({required this.session, required this.nav});

  final SongModalSession session;
  final ContextModalNav nav;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodyLarge;
    final color = Theme.of(context).colorScheme.primary;
    // The InkWell fills its whole half of the footer, so hover and ink cover
    // it all rather than a blob around the label.
    Widget button(Key key, IconData icon, String label, QueueAction action) =>
        Expanded(
          child: InkWell(
            key: key,
            onTap: () {
              nav.close();
              session.queue(action);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  Icon(icon, size: 20, color: color),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: style?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Row(
          children: [
            button(
              const ValueKey('song-modal-play-next'),
              AppIcons.playlistPlay,
              l10n.queuePlayNext,
              QueueAction.playNext,
            ),
            button(
              const ValueKey('song-modal-add-to-queue'),
              AppIcons.addToQueue,
              l10n.queueAddToQueue,
              QueueAction.addToQueue,
            ),
          ],
        ),
      ],
    );
  }
}
