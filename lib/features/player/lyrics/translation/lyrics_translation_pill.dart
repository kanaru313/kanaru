import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/lyrics_plugins/plugin_icon.dart';
import '../../../../shared/translation_language_name.dart';
import '../../now_playing/now_playing_header_pill.dart';

/// Smallest room, in logical pixels, for which the translate button grows a
/// label; below it the button stays the round icon.
const lyricsTranslationMinLabelWidth = 64.0;

/// Width of the pill beside its label: padding (10 + 14), the 18 px logo and
/// the gap after it (8).
const lyricsTranslationPillChrome = 50.0;

/// The translate button of translated lyrics: the plugin's [PluginIcon]
/// followed by the target language name, as a [NowPlayingHeaderPill], or a
/// progress ring while [busy]. Pressing it runs [onPressed].
class LyricsTranslationPill extends ConsumerWidget {
  const LyricsTranslationPill({
    super.key,
    required this.state,
    required this.tooltip,
    required this.maxLabelWidth,
    required this.onPressed,
    this.busy = false,
  });

  /// The state the pill shows; its service and target language pick the icon
  /// and label.
  final TranslationReady state;

  final String tooltip;

  /// Most room the label may take.
  final double maxLabelWidth;

  final VoidCallback? onPressed;

  /// Whether a background retranslate is running; shows a spinner in place of
  /// the plugin icon.
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final serviceId = state.service.value;
    final record = ref.watch(
      lyricsPluginRecordsProvider.select((records) {
        for (final r in records) {
          if (r.installId == serviceId) return r;
        }
        return null;
      }),
    );
    return NowPlayingHeaderPill(
      leading: PluginIcon(record: record, size: 18),
      busy: busy,
      label: translationLanguageName(l10n, state.info.effective),
      tooltip: tooltip,
      maxLabelWidth: maxLabelWidth,
      onPressed: onPressed,
    );
  }
}
