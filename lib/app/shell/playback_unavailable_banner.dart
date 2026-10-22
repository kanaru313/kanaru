import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/player_service.dart';
import '../../core/player/unavailable_audio_backend.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// Tells the user playback is off because the audio engine (libmpv) was not
/// found. Shown exactly while the active backend is the stand-in, so it also
/// covers an engine that failed late, when it was first created. Not
/// dismissible: playback stays off for the whole session.
class PlaybackUnavailableBanner extends ConsumerWidget {
  const PlaybackUnavailableBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(audioBackendProvider) is! UnavailableAudioBackend) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(AppIcons.volumeOff, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.playbackUnavailableTitle,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: colors.onErrorContainer),
                  ),
                  Text(
                    l10n.playbackUnavailableBody,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onErrorContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
