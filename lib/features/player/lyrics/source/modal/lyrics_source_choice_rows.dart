import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/lyrics/online/lyrics_choice.dart';
import '../../../../../core/lyrics/online/lyrics_source_names.dart';
import '../../../../../core/lyrics/online/lyrics_target.dart';
import '../../../../../core/lyrics/playing_local_lyrics_provider.dart';
import '../../../../../core/lyrics/online/playing_lyrics_source_provider.dart';
import '../../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../../../../core/settings/settings_provider.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/lyrics_picker/lyrics_source_name_text.dart';
import '../../../../../shared/lyrics_plugins/plugin_icon.dart';
import '../../../../../shared/widgets/layered_modal/layered_modal_stack.dart';
import '../../../../../shared/widgets/selection_row.dart';
import '../lyrics_source_labels.dart';
import '../lyrics_source_menu_item.dart';
import 'lyrics_source_modal_run.dart';

/// The three choices of the lyrics source modal as [SelectionRow]s: lyrics in
/// the file, the online version, and no lyrics. The row of the choice in
/// effect is selected. Tapping a row builds the runner, closes the modal
/// stack and then calls `choose`; tapping the selected row only closes.
///
/// With [enabled] false (the song is not a local file, or the sources are
/// still loading) every row is disabled.
class LyricsSourceChoiceRows extends ConsumerWidget {
  const LyricsSourceChoiceRows({
    super.key,
    required this.source,
    required this.messenger,
    required this.enabled,
  });

  final LyricsSourceResolution source;
  final ScaffoldMessengerState? messenger;
  final bool enabled;

  void _choose(BuildContext context, LyricsChoice choice) {
    if (source.effective == choice) {
      closeLayeredModalStack(context);
      return;
    }
    closeStackThenRun(
      context,
      source: source,
      messenger: messenger,
      action: (runner) => runner.choose(choice),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final effective = source.effective;
    final status = source.status;
    final pin = source.pin;
    final origin = status is LyricsFound ? status.origin : null;
    final names = ref.watch(lyricsSourceNamesProvider);
    final records = ref.watch(lyricsPluginRecordsProvider);
    final autoPossible =
        ref.watch(settingsProvider.select((s) => s.onlineLyrics.autoAllowed)) &&
        ref.watch(lyricsSourcesProvider).any((e) => e.enabled) &&
        (ref.watch(lyricsTargetProvider).value?.isAutoSearchable ?? false);

    // Local row.
    // Read only for this song: the provider holds the previous song's value
    // while the next one loads.
    final own = ref.watch(playingLocalLyricsProvider).value;
    final ownLyrics = own != null && own.uri == status.uri ? own.lyrics : null;
    final ownLabel = ownLyrics == null
        ? null
        : lyricsSourceLocalSubtitle(l10n, ownLyrics.source);
    final localSubtitle = !source.hasLocal
        ? l10n.lyricsSourceRowFileNone
        : ownLabel == null
        ? null
        : l10n.lyricsSourceOnline(
            ownLabel,
            lyricsSourceKind(l10n, ownLyrics!.synced),
          );

    // Online row: the record on screen, else the stored pick.
    final providerId = origin?.providerId ?? pin?.providerId;
    final synced = status is LyricsFound && origin != null
        ? status.lyrics.synced
        : pin?.lyrics?.synced;
    final onlineEnabled =
        pin?.hasPick == true ||
        effective == LyricsChoice.online ||
        (source.chosen == LyricsChoice.off && !source.hasLocal && autoPossible);
    String? onlineSubtitle;
    Widget? onlineLeading;
    if (providerId == null) {
      onlineSubtitle = onlineEnabled ? null : l10n.lyricsSourceRowOnlineNone;
    } else {
      final name = lyricsSourceNameText(l10n, names, providerId);
      final detail = synced == null
          ? name
          : l10n.lyricsSourceOnline(name, lyricsSourceKind(l10n, synced));
      onlineSubtitle = origin != null && !origin.pinned
          ? l10n.lyricsSourceRowOnlineAuto(detail)
          : detail;
      final record = records
          .where((r) => r.installId == providerId)
          .firstOrNull;
      onlineLeading = PluginIcon(record: record, size: 24, letterOf: name);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectionRow(
          title: l10n.lyricsSourceLocalItem,
          subtitle: localSubtitle,
          selected: effective == LyricsChoice.local,
          onTap: enabled && source.hasLocal
              ? () => _choose(context, LyricsChoice.local)
              : null,
        ),
        SelectionRow(
          title: l10n.lyricsSourceOnlineVersion,
          subtitle: onlineSubtitle,
          leading: onlineLeading,
          selected: effective == LyricsChoice.online,
          onTap: enabled && onlineEnabled
              ? () => _choose(context, LyricsChoice.online)
              : null,
        ),
        SelectionRow(
          title: l10n.lyricsSourceRowOff,
          selected: effective == LyricsChoice.off,
          onTap: enabled ? () => _choose(context, LyricsChoice.off) : null,
        ),
      ],
    );
  }
}
