import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/track_details/track_details.dart';
import '../../../core/track_details/track_details_provider.dart';
import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../../widgets/context_modal/context_modal_route.dart';
import '../../widgets/favorite_button.dart';
import '../song_modal_session.dart';
import '../lyrics/song_lyrics_card.dart';
import 'remembered_scroll_controller.dart';
import 'song_info_field.dart';
import 'song_info_groups.dart';
import 'song_info_hero.dart';

/// The Song info page: the song's tags, audio and file facts, read from the
/// library row (no file is opened). Unknown fields show only while the eye
/// is on; the choice is kept in the display settings.
ContextModalPage songInfoPage(SongModalSession session) => ContextModalPage(
  key: 'song-info',
  scrollController: RememberedScrollController(),
  headerBuilder: (context, nav) => ContextModalTopBar(
    title: context.l10n.songInfoTitle,
    onBack: nav.pop,
    actions: [
      const _ShowUnknownButton(),
      FavoriteButton(path: session.song.path),
      IconButton(
        tooltip: context.l10n.songInfoPreview,
        icon: const Icon(AppIcons.previewPlay),
        onPressed: null,
      ),
    ],
  ),
  bodyBuilder: (context, nav) => [
    Consumer(
      builder: (context, ref, _) {
        final details = ref.watch(trackDetailsProvider(session.song.id));
        return details.when(
          data: (d) => d == null
              ? _Message(text: context.l10n.songInfoGone, onBack: nav.pop)
              : _InfoBody(details: d, session: session, nav: nav),
          loading: () => const _Skeleton(),
          error: (_, _) =>
              _Message(text: context.l10n.songInfoLoadFailed, onBack: nav.pop),
        );
      },
    ),
  ],
);

/// The eye: shows or hides the fields a song has no value for.
class _ShowUnknownButton extends ConsumerWidget {
  const _ShowUnknownButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final show = ref.watch(
      settingsProvider.select((s) => s.display.songInfoShowUnknown),
    );
    return IconButton(
      tooltip: show ? l10n.songInfoHideUnknown : l10n.songInfoShowUnknown,
      isSelected: show,
      icon: Icon(show ? AppIcons.visibility : AppIcons.visibilityOff),
      onPressed: () {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.setDisplay(
          ref
              .read(settingsProvider)
              .display
              .copyWith(songInfoShowUnknown: !show),
        );
      },
    );
  }
}

class _InfoBody extends ConsumerWidget {
  const _InfoBody({
    required this.details,
    required this.session,
    required this.nav,
  });

  final TrackDetails details;
  final SongModalSession session;
  final ContextModalNav nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(
      settingsProvider.select((s) => s.display.songInfoShowUnknown),
    );
    final groups = buildSongInfoGroups(
      context.l10n,
      details,
      now: DateTime.now(),
    );
    final lyricsPath = details.localPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SongInfoHero(details: details),
        for (final group in groups) ...[
          SongInfoGroupHeading(title: group.title),
          for (final field in group.visibleFields(showUnknown: show))
            SongInfoFieldTile(
              key: ValueKey('song-info-${field.id}'),
              field: field,
            ),
          // The lyrics sit between the Tags and Audio groups.
          if (group.id == 'tags' && lyricsPath != null)
            SongLyricsCard(session: session, path: lyricsPath, nav: nav),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Grey bars where the fields will be while the row loads.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        key: const ValueKey('song-info-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          for (final width in const [0.7, 0.5, 0.6, 0.4, 0.65, 0.55])
            FractionallySizedBox(
              widthFactor: width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const SizedBox(height: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// The song is gone (or could not be read): the text and a way back.
class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onBack});

  final String text;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Text(text, textAlign: TextAlign.center),
        TextButton(
          onPressed: onBack,
          child: Text(context.l10n.contextModalBack),
        ),
      ],
    ),
  );
}
