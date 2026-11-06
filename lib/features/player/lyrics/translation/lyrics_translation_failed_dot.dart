import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_state.dart';

/// Size of the dot that marks a failed translation.
const _dotSize = 8.0;

/// Whether the header button marks [state] as failed: a failed translation,
/// or a shown translation whose retranslate failed.
bool translationShowsFailure(LyricsTranslationState state) =>
    state is TranslationFailed ||
    (state is TranslationReady && state.retranslateFailure != null) ||
    (state is TranslationSameLanguage && state.retranslateFailure != null);

/// The error dot at a corner of the header button; place it inside a [Stack].
class LyricsTranslationFailedDot extends StatelessWidget {
  const LyricsTranslationFailedDot({
    super.key,
    required this.top,
    required this.right,
  });

  final double top;
  final double right;

  @override
  Widget build(BuildContext context) => Positioned(
    top: top,
    right: right,
    child: IgnorePointer(
      child: Container(
        key: const ValueKey('translationFailedDot'),
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
