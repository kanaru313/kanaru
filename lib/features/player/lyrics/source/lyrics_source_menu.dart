import 'package:material_ui/material_ui.dart';

import '../../../../core/database/library_startup.dart';
import '../../../../core/lyrics/lyrics.dart';
import '../../../../core/lyrics/online/lyrics_choice.dart';
import '../../../../core/lyrics/online/lyrics_provider_registry.dart';
import '../../../../core/lyrics/online/playing_lyrics_status.dart';
import '../../../../core/player/local_path_of.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/format_duration.dart';
import '../lyrics_action_runner.dart';
import '../lyrics_credit_row.dart' show lyricsProviderName;
import 'lyrics_source_labels.dart';

/// Items of the lyrics source menu, for the song and lyrics source the
/// [runner] captured when the menu opened. Every item, and the dialogs they
/// open, act on that snapshot, so a track change while the menu is open
/// cannot redirect them. [ownSource] is where the song's own lyrics came
/// from, read when the menu opened. [firstItemFocus] goes to the first item, which is
/// what a keyboard open focuses.
///
/// Choosing needs the library and a local file; without them those items
/// are disabled and "Find lyrics online…" is left out.
List<Widget> lyricsSourceMenuItems(
  BuildContext context,
  LyricsActionRunner runner,
  List<LyricsProviderRegistration> providers, {
  LyricsSource? ownSource,
  FocusNode? firstItemFocus,
}) {
  final source = runner.source;
  if (source == null || runner.target == null) return const [];
  final l10n = context.l10n;
  final status = source.status;
  final found = status is LyricsFound ? status : null;
  final origin = runner.origin;
  final pin = source.pin;
  final hasPick = pin?.hasPick ?? false;
  final registration = providers.firstOrNull;
  final canChoose =
      runner.container.read(libraryDatabaseProvider) != null &&
      localPathOf(status.uri) != null;
  final effective = source.effective;

  VoidCallback? when(bool enabled, VoidCallback action) =>
      enabled ? action : null;

  final autoText = found != null && effective == LyricsChoice.auto
      ? l10n.lyricsSourceAutoNow(lyricsSourceDetail(l10n, found, providers))
      : l10n.lyricsSourceAutoHint(registration?.displayName ?? '');
  final pickKind = pin?.lyrics?.synced;
  final pickLength = pin?.remoteDurationMs;
  final pickSubtitle = [
    ?(pickKind == null ? null : lyricsSourceKind(l10n, pickKind)),
    ?(pickLength == null
        ? null
        : formatDuration(Duration(milliseconds: pickLength))),
  ];

  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        l10n.lyricsSourceMenuHeader,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
    _item(
      context,
      focusNode: firstItemFocus,
      title: l10n.lyricsSourceAutoItem,
      subtitle: hasPick ? l10n.lyricsSourceForgetPick(autoText) : autoText,
      checked: effective == LyricsChoice.auto,
      onPressed: when(canChoose, () => runner.choose(LyricsChoice.auto)),
    ),
    const Divider(height: 9),
    if (source.hasLocal || source.chosen == LyricsChoice.local)
      _item(
        context,
        title: l10n.lyricsSourceLocalItem,
        subtitle: !source.hasLocal
            ? l10n.lyricsSourceLocalMissing
            : _localSubtitle(l10n, ownSource),
        checked: effective == LyricsChoice.local,
        onPressed: when(
          canChoose && source.hasLocal,
          () => runner.choose(LyricsChoice.local),
        ),
      ),
    if (hasPick)
      _item(
        context,
        title: l10n.lyricsSourceOnlineItem(
          lyricsProviderName(providers, pin?.providerId ?? ''),
        ),
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
    if (origin != null &&
        !origin.pinned &&
        (!hasPick || pin?.remoteId == origin.remoteId))
      _item(
        context,
        title: l10n.lyricsSourceKeep,
        onPressed: when(canChoose, runner.keep),
      ),
    if (origin != null)
      _item(
        context,
        title: l10n.lyricsMenuNotThese,
        onPressed: when(canChoose, runner.reject),
      ),
    if (registration != null && canChoose)
      _item(
        context,
        title: l10n.lyricsFindOnline,
        onPressed: runner.findOnline,
      ),
    _item(
      context,
      title: l10n.lyricsSourceSave,
      onPressed: when(canChoose && origin != null, runner.save),
    ),
    const Divider(height: 9),
    _item(
      context,
      title: l10n.lyricsSourceTurnOff,
      checked: effective == LyricsChoice.off,
      onPressed: when(canChoose, () => runner.choose(LyricsChoice.off)),
    ),
  ];
}

/// "`.lrc` file" or "In the tag", from where the song's own lyrics come from.
String? _localSubtitle(AppLocalizations l10n, LyricsSource? own) =>
    switch (own) {
      LyricsSource.sidecar => l10n.lyricsSourceFile,
      LyricsSource.embedded => l10n.lyricsSourceLocalTag,
      null => null,
    };

/// One row: a check mark column, the title and an optional subtitle.
Widget _item(
  BuildContext context, {
  required String title,
  required VoidCallback? onPressed,
  String? subtitle,
  bool checked = false,
  FocusNode? focusNode,
}) {
  final theme = Theme.of(context);
  return MenuItemButton(
    focusNode: focusNode,
    onPressed: onPressed,
    leadingIcon: SizedBox(
      width: 20,
      child: checked
          ? Icon(
              Icons.check_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            )
          : null,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if (subtitle != null)
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    ),
  );
}
