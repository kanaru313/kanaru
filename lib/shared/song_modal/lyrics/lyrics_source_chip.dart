import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/lyrics/online/lyrics_source_names.dart';
import '../../../core/lyrics/track_lyrics_preview_provider.dart';
import '../../../l10n/l10n.dart';

/// A small rounded label in the lyrics card header.
class LyricsInfoChip extends StatelessWidget {
  const LyricsInfoChip({
    super.key,
    required this.label,
    this.highlight = false,
  });

  final String label;

  /// Drawn in the primary container colors (the "Synced" chip).
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight
            ? colors.primaryContainer
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: highlight
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Names where [preview] came from: the `.lrc` file, the tags, or the online
/// source (by its display name, else its id).
class LyricsSourceChip extends ConsumerWidget {
  const LyricsSourceChip({super.key, required this.preview});

  final TrackLyricsPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = preview.onlineProviderId;
    final label = switch (preview.kind) {
      TrackLyricsKind.sidecar => l10n.songLyricsSidecar,
      TrackLyricsKind.embedded => l10n.songLyricsEmbedded,
      TrackLyricsKind.online => l10n.songLyricsOnline(
        ref.watch(
          lyricsSourceNamesProvider.select((m) => m[id]?.displayName ?? id),
        )!,
      ),
    };
    return LyricsInfoChip(label: label);
  }
}
