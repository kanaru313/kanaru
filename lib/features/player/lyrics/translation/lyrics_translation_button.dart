import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../core/settings/settings_provider.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/icons/app_icons.dart';
import '../../playback_controls.dart';
import 'lyrics_translation_labels.dart';
import 'lyrics_translation_menu.dart';
import 'lyrics_translation_pill.dart';

/// Size of the dot that marks a failed translation.
const _dotSize = 8.0;

/// Header button that opens the lyrics translation menu; it never toggles.
/// Off, it is a plain icon; on, the icon is the primary colour on a raised
/// background; while translating a ring turns around it; after a failure an
/// error dot sits at its corner. With translated lyrics and room for a label
/// it grows into a pill that names the service and language. Icon and pill
/// share one menu anchor, so an open menu survives the switch. Only this
/// widget watches the translation, so a change rebuilds the button and
/// nothing around it.
class LyricsTranslationButton extends ConsumerStatefulWidget {
  const LyricsTranslationButton({
    super.key,
    this.onMenuChanged,
    this.enabled = true,
    this.maxLabelWidth,
  });

  /// Called with `true` when the menu opens and `false` when it closes, also
  /// when the button leaves the tree with the menu open. The menu floats in
  /// the overlay, so a parent that hides itself on inactivity needs this.
  final ValueChanged<bool>? onMenuChanged;

  /// False when the song has no lyrics to translate.
  final bool enabled;

  /// Room for the pill's label; `null` or less than
  /// [lyricsTranslationMinLabelWidth] keeps the round icon.
  final double? maxLabelWidth;

  @override
  ConsumerState<LyricsTranslationButton> createState() =>
      _LyricsTranslationButtonState();
}

class _LyricsTranslationButtonState
    extends ConsumerState<LyricsTranslationButton> {
  final _menu = MenuController();
  bool _open = false;

  void _setOpen(bool open) {
    if (_open == open) return;
    _open = open;
    widget.onMenuChanged?.call(open);
  }

  @override
  void dispose() {
    _setOpen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final appLang = Localizations.localeOf(context).languageCode;
    final state = ref.watch(lyricsTranslationProvider(appLang));
    // Watched so a changed setting rebuilds the open menu.
    ref.watch(settingsProvider.select((s) => s.translation));
    final active = translationIsActive(state);
    final usable = widget.enabled && state is! TranslationUnavailable;
    if (!usable && _open) {
      // The menu would be empty or stale: close it once this frame is done.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) _menu.close();
      });
    }

    return MenuAnchor(
      controller: _menu,
      onOpen: () => _setOpen(true),
      onClose: () => _setOpen(false),
      menuChildren: lyricsTranslationMenuItems(context, ref, state, appLang),
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        final room = widget.maxLabelWidth ?? 0;
        if (state is TranslationReady &&
            room >= lyricsTranslationMinLabelWidth) {
          return LyricsTranslationPill(
            state: state,
            maxLabelWidth: room,
            onPressed: usable ? toggle : null,
          );
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(AppIcons.lyricsTranslateOutlined),
              selectedIcon: const Icon(AppIcons.lyricsTranslate),
              isSelected: active,
              iconSize: playerIconSize,
              style: active
                  ? IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                      foregroundColor: scheme.primary,
                    )
                  : null,
              tooltip: translationButtonTooltip(l10n, state),
              onPressed: usable ? toggle : null,
            ),
            if (state is TranslationLoading)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (state is TranslationFailed)
              Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: Container(
                    key: const ValueKey('translationFailedDot'),
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
