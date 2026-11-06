import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/online/lyrics_provider.dart';
import '../../l10n/l10n.dart';
import '../format_duration.dart';
import '../icons/app_icons.dart';
import '../widgets/layered_modal/layered_modal_route.dart';

/// Title of the Choose lyrics dialog with the song line under it. A back arrow
/// shows only while the dialog is stacked over another modal; it pops the
/// picker and leaves that modal open.
class LyricsPickerTitleRow extends StatelessWidget {
  const LyricsPickerTitleRow({super.key, required this.query});

  final LyricsQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final duration = query.duration;
    final stacked = LayeredModalDepth.of(context) >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (stacked) ...[
              IconButton(
                tooltip: l10n.lyricsPickerBack,
                icon: const Icon(AppIcons.back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                l10n.lyricsPickerTitle,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.lyricsPickerSong(
            query.title ?? '-',
            query.artist ?? '-',
            duration == null ? '-' : formatDuration(duration),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
