import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/database/library_startup.dart';
import '../../../core/indexer/cover_paths.dart';
import '../../../core/track_details/track_details.dart';
import '../../../l10n/l10n.dart';
import '../../icons/app_icons.dart';
import '../../widgets/cover_art.dart';

const double songInfoCoverSize = 136;

/// The cover and the play statistics of the song.
class SongInfoHero extends ConsumerWidget {
  const SongInfoHero({super.key, required this.details});

  final TrackDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd(l10n.localeName);
    String day(int ms) => date.format(DateTime.fromMillisecondsSinceEpoch(ms));
    final first = details.firstPlayedAt;
    final last = details.lastPlayedAt;
    final played = details.playCount > 0;
    Widget stat(IconData icon, String text) => Row(
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        spacing: 16,
        children: [
          CoverArt(
            path: coverPath(
              ref.watch(coverCacheDirectoryProvider),
              details.coverKey,
            ),
            size: songInfoCoverSize,
            placeholder: const Center(child: Icon(AppIcons.musicNoteOutlined)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                stat(
                  AppIcons.headphones,
                  l10n.songInfoPlays(details.playCount),
                ),
                if (played && first != null)
                  stat(AppIcons.schedule, l10n.songInfoFirstPlayed(day(first)))
                else if (!played)
                  stat(AppIcons.schedule, l10n.songInfoNeverPlayed),
                if (played && last != null)
                  stat(AppIcons.history, l10n.songInfoLastPlayed(day(last))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
