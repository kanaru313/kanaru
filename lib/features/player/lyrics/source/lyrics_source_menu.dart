import 'package:material_ui/material_ui.dart';

import '../../../../core/database/library_startup.dart';
import '../../../../core/lyrics/lyrics.dart';
import '../../../../core/lyrics/online/lyrics_choice.dart';
import '../../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../../core/lyrics/online/lyrics_source_names.dart';
import '../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../core/player/local_path_of.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/format_duration.dart';
import '../../../../shared/icons/app_icons.dart';
import '../lyrics_action_runner.dart';
import '../lyrics_provider_name.dart';
import 'lyrics_source_labels.dart';
import 'lyrics_source_menu_item.dart';

/// Items of the lyrics source menu, for the song and lyrics source the
/// [runner] captured when the menu opened. Every item, and the dialogs they
/// open, act on that snapshot, so a track change while the menu is open
/// cannot redirect them. [ownSource] is where the song's own lyrics came
/// from, read when the menu opened. [firstItemFocus] goes to the first item,
/// which is what a keyboard open focuses. [headerFocus] is on the header, a
/// place for the focus when that item is disabled: a menu that holds the
/// focus gets Escape, one that does not leaves it to the screen behind.
///
/// Choosing needs the library and a local file; without them those items
/// are disabled and "Find lyrics online…" is left out.
List<Widget> lyricsSourceMenuItems(
  BuildContext context,
  LyricsActionRunner runner,
  List<LyricsProviderRegistration> providers,
  Map<String, LyricsSourceName> names, {
  LyricsSource? ownSource,
  FocusNode? firstItemFocus,
  FocusNode? headerFocus,
}) {
  final source = runner.source;
  if (source == null || runner.target == null) return const [];
  final l10n = context.l10n;
  final status = source.status;
  final found = status is LyricsFound ? status : null;
  final origin = runner.origin;
  final pin = source.pin;
  final hasPick = pin?.hasPick ?? false;
  final canChoose =
      runner.container.read(libraryDatabaseProvider) != null &&
      localPathOf(status.uri) != null;
  final effective = source.effective;

  VoidCallback? when(bool enabled, VoidCallback action) =>
      enabled ? action : null;

  final autoText = found != null && effective == LyricsChoice.auto
      ? l10n.lyricsSourceAutoNow(lyricsSourceDetail(l10n, found, names))
      // No source names: the list grows with every plugin, and the
      // Sources page shows their order.
      : providers.isEmpty
      ? l10n.lyricsSourceAutoHintLocalOnly
      : l10n.lyricsSourceAutoHint;
  final pickKind = pin?.lyrics?.synced;
  final pickLength = pin?.remoteDurationMs;
  final pickSubtitle = [
    ?(pickKind == null ? null : lyricsSourceKind(l10n, pickKind)),
    ?(pickLength == null
        ? null
        : formatDuration(Duration(milliseconds: pickLength))),
  ];

  // With lyrics off the choices stay, dimmed: pressing one turns them on.
  Widget choice(Widget item) =>
      effective == LyricsChoice.off ? Opacity(opacity: 0.4, child: item) : item;

  return [
    Focus(
      focusNode: headerFocus,
      skipTraversal: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Text(
          l10n.lyricsSourceMenuSection.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    choice(
      lyricsSourceMenuItem(
        context,
        focusNode: firstItemFocus,
        title: l10n.lyricsSourceAutoItem,
        subtitle: hasPick ? l10n.lyricsSourceForgetPick(autoText) : autoText,
        checked: effective == LyricsChoice.auto,
        onPressed: when(canChoose, () => runner.choose(LyricsChoice.auto)),
      ),
    ),
    if (source.hasLocal || source.chosen == LyricsChoice.local)
      choice(
        lyricsSourceMenuItem(
          context,
          title: l10n.lyricsSourceLocalItem,
          subtitle: !source.hasLocal
              ? l10n.lyricsSourceLocalMissing
              : lyricsSourceLocalSubtitle(l10n, ownSource),
          checked: effective == LyricsChoice.local,
          onPressed: when(
            canChoose && source.hasLocal,
            () => runner.choose(LyricsChoice.local),
          ),
        ),
      ),
    if (hasPick)
      choice(
        lyricsSourceMenuItem(
          context,
          title: lyricsSourceNameText(l10n, names, pin?.providerId ?? ''),
          tag: l10n.lyricsSourceChosenTag,
          subtitle: switch (pickSubtitle) {
            [] => null,
            [final one] => one,
            [final kind, final length] => l10n.lyricsSourceOnlineSubtitle(
              kind,
              length,
            ),
            _ => null,
          },
          checked: effective == LyricsChoice.online,
          onPressed: when(canChoose, () => runner.choose(LyricsChoice.online)),
        ),
      ),
    const Divider(height: 9),
    if (origin != null &&
        !origin.pinned &&
        (!hasPick || pin?.remoteId == origin.remoteId))
      lyricsSourceMenuItem(
        context,
        icon: AppIcons.lyricsKeep,
        title: l10n.lyricsSourceKeep,
        onPressed: when(canChoose, runner.keep),
      ),
    if (providers.isNotEmpty && canChoose)
      lyricsSourceMenuItem(
        context,
        icon: AppIcons.search,
        title: l10n.lyricsFindOnline,
        onPressed: runner.findOnline,
      ),
    lyricsSourceMenuItem(
      context,
      icon: AppIcons.lyricsSave,
      title: l10n.lyricsSourceSave,
      onPressed: when(canChoose && origin != null, runner.save),
    ),
    if (origin != null)
      lyricsSourceMenuItem(
        context,
        icon: AppIcons.lyricsReject,
        title: l10n.lyricsMenuNotThese,
        onPressed: when(canChoose, runner.reject),
      ),
    const Divider(height: 9),
    lyricsSourceSwitchItem(
      context,
      title: l10n.lyricsSourceSwitch,
      on: effective != LyricsChoice.off,
      // Turning it back on goes to Automatic, whatever was chosen before.
      onChanged: canChoose
          ? (on) => runner.choose(on ? LyricsChoice.auto : LyricsChoice.off)
          : null,
    ),
  ];
}
