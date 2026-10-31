import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/lyrics_translation/lyrics_translation_controller.dart';
import '../../../../core/lyrics_translation/lyrics_translation_state.dart';
import '../../../../core/lyrics_translation/translation_language.dart';
import '../../../../core/lyrics_translation/translation_service.dart';
import '../../../../core/settings/settings_provider.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/translation_language_name.dart';
import '../../../../shared/translation_notice_dialog.dart';
import '../../../../shared/widgets/menu_row.dart';
import 'lyrics_translation_labels.dart';
import 'lyrics_translation_menu_footer.dart';
import 'lyrics_translation_switch_row.dart';

/// Value of the "Default" item of the language submenu.
const _defaultLanguage = '';

/// Items of the lyrics translation menu: the switch, the language submenu,
/// the service submenu, the display style as a segmented button and a footer
/// about the saved translation.
/// Call it from the `build` of the widget that anchors the menu, so the open
/// menu follows [state] and the settings. [context] is the anchor's: the
/// network notice opens on it. [appLang] picks the controller.
/// [firstItemFocus] is on a wrapper of the switch row, so the open menu holds
/// the focus (Escape closes it) and Enter or Space flips the switch.
List<Widget> lyricsTranslationMenuItems(
  BuildContext context,
  WidgetRef ref,
  LyricsTranslationState state,
  String appLang, {
  FocusNode? firstItemFocus,
}) {
  final info = translationInfoOf(state);
  if (info == null) return const [];
  final l10n = context.l10n;
  final prefs = ref.watch(settingsProvider.select((s) => s.translation));
  final settings = ref.read(settingsProvider.notifier);
  final controller = ref.read(lyricsTranslationProvider(appLang).notifier);
  final on = prefs.show && !prefs.needsNotice;

  void toggle() => on
      ? settings.toggleLyricsTranslation()
      : enableTranslationWithNotice(context, ref, prefs.service);

  Future<void> pickService(LyricsTranslationService service) async {
    if (prefs.show && !prefs.noticeAcknowledged.contains(service)) {
      await enableTranslationWithNotice(context, ref, service);
    } else {
      settings.setTranslation(prefs.copyWith(service: service));
    }
  }

  // A radio row of a submenu; the one in effect is tinted like the lyrics
  // source menu's.
  final scheme = Theme.of(context).colorScheme;
  Widget radio<T>({
    required T value,
    required T groupValue,
    required VoidCallback onChanged,
    required String label,
  }) => RadioMenuButton<T>(
    style: menuRowStyle(
      background: value == groupValue ? menuRowSelectedTint(scheme) : null,
    ),
    value: value,
    groupValue: groupValue,
    onChanged: (_) => onChanged(),
    child: Text(label),
  );

  return [
    lyricsTranslationSwitchRow(
      context,
      on: on,
      onToggle: toggle,
      focusNode: firstItemFocus,
    ),
    menuRowSpaced(
      SubmenuButton(
        style: menuRowStyle(),
        menuChildren: [
          radio<String>(
            value: _defaultLanguage,
            groupValue: info.songOverride ?? _defaultLanguage,
            onChanged: () => controller.setSongTarget(null),
            label: l10n.lyricsTranslationTargetDefault(
              translationLanguageName(l10n, info.defaultTarget),
            ),
          ),
          for (final language in translationLanguages)
            radio<String>(
              value: language.code,
              groupValue: info.songOverride ?? _defaultLanguage,
              onChanged: () => controller.setSongTarget(language.code),
              label: translationLanguageName(l10n, language),
            ),
        ],
        child: Text(
          l10n.lyricsTranslationTarget(
            translationLanguageName(l10n, info.effective),
          ),
        ),
      ),
    ),
    menuRowSpaced(
      SubmenuButton(
        style: menuRowStyle(),
        trailingIcon: Text(
          translationServiceName(prefs.service),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        menuChildren: [
          for (final service in LyricsTranslationService.values)
            radio<LyricsTranslationService>(
              value: service,
              groupValue: prefs.service,
              onChanged: () => pickService(service),
              label: translationServiceName(service),
            ),
        ],
        child: Text(l10n.lyricsTranslationServiceHeader),
      ),
    ),
    menuSectionLabel(context, l10n.lyricsTranslationDisplayHeader),
    // Not a menu item: the menu stays open so the result shows at once.
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SegmentedButton<LyricsTranslationDisplay>(
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        segments: [
          ButtonSegment(
            value: LyricsTranslationDisplay.underLine,
            label: Text(l10n.lyricsTranslationDisplayUnder),
          ),
          ButtonSegment(
            value: LyricsTranslationDisplay.replace,
            label: Text(l10n.lyricsTranslationDisplayReplace),
          ),
        ],
        selected: {prefs.display},
        onSelectionChanged: (s) =>
            settings.setTranslation(prefs.copyWith(display: s.single)),
      ),
    ),
    ...lyricsTranslationMenuFooter(context, state, prefs.service, controller),
  ];
}
