import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lyrics/plugins/lyrics_sources_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_source_routes.dart';
import 'lyrics_setting_rows.dart';
import 'lyrics_translation_setting_rows.dart';
import 'settings_section.dart';

/// Name of the built-in source in the row's subtitle.
const _lrclibName = 'LRCLIB';

/// Everything about lyrics in one place: which sources to use, which lyrics
/// to prefer, the online lookup and its permission, saved lyrics, and lyrics
/// translation.
class LyricsSettingsSection extends StatelessWidget {
  const LyricsSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: context.l10n.settingsLyrics,
      children: const [
        _LyricsSourcesRow(),
        LyricsSettingRows(),
        LyricsTranslationSettingRows(),
      ],
    );
  }
}

/// "Lyrics sources": names the sources that are on, in the user's order, and
/// opens the page where they are ordered and set up.
class _LyricsSourcesRow extends ConsumerWidget {
  const _LyricsSourcesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final loaded = ref.watch(lyricsSourcesLoadedProvider);
    final on = [
      for (final source in ref.watch(lyricsSourcesProvider))
        if (source.enabled) source.record?.name ?? _lrclibName,
    ];
    return ListTile(
      title: Text(l10n.lyricsSourcesTitle),
      // Until the list is read it holds LRCLIB alone, which would be wrong.
      subtitle: !loaded
          ? null
          : Text(
              on.isEmpty
                  ? l10n.lyricsSourcesRowNoneOn
                  : l10n.lyricsSourcesRowSubtitle(on.join(', '), on.length),
            ),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () => context.go(lyricsSourcesRoute),
    );
  }
}
