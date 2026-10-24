import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/player_service.dart';
import '../../../shared/icons/app_icons.dart';

/// The equalizer glyph of the playing row while audio plays, in the primary
/// color; an empty slot of the same size while paused so the row does not
/// shift. Only this widget rebuilds when playback starts or pauses.
class QueuePlayingIndicator extends ConsumerWidget {
  const QueuePlayingIndicator({super.key});

  static const size = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(playerServiceProvider.select((s) => s.playing));
    return SizedBox.square(
      dimension: size,
      child: playing
          ? Icon(
              AppIcons.equalizerRounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }
}
