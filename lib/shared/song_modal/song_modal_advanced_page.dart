import '../../l10n/l10n.dart';
import '../icons/app_icons.dart';
import '../widgets/context_modal/context_modal_route.dart';
import 'song_modal_data.dart';
import 'song_modal_session.dart';

/// The Advanced page: Find lyrics online and the actions not available yet.
/// Reads nothing from providers, so it needs only the [session].
ContextModalPage songModalAdvancedPage(
  SongModalSession session, {
  required bool hasLibrary,
}) => ContextModalPage(
  key: 'song-advanced',
  headerBuilder: (context, nav) => ContextModalTopBar(
    title: context.l10n.songModalAdvanced,
    onBack: nav.pop,
  ),
  bodyBuilder: (context, nav) => contextModalSections(
    nav,
    songModalAdvancedSections(
      context.l10n,
      SongModalData(
        song: session.song,
        links: null,
        isFavorite: null,
        hasLibrary: hasLibrary,
        canFindLyrics: session.lyricsTarget != null,
      ),
      session.handlers(),
    ),
  ),
);

/// The rows of the Advanced page: Find lyrics online (when [data] allows),
/// then the actions that are not available yet.
List<List<ContextModalAction>> songModalAdvancedSections(
  AppLocalizations l10n,
  SongModalData data,
  SongModalHandlers h,
) => [
  [
    if (data.canFindLyrics)
      ContextModalAction(
        id: 'find-lyrics',
        icon: AppIcons.lyrics,
        label: l10n.lyricsFindOnline,
        onTap: songModalCloseThen(h.findLyrics),
      ),
  ],
  [
    ContextModalAction(
      id: 'remove-from-library',
      icon: AppIcons.removeFromLibrary,
      label: l10n.songModalRemoveFromLibrary,
      comingSoon: true,
    ),
    ContextModalAction(
      id: 'delete-file',
      icon: AppIcons.deleteOutline,
      label: l10n.songModalDeleteFile,
      comingSoon: true,
    ),
  ],
];
