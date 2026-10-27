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
import 'lyrics_translation_labels.dart';

/// Value of the "Default" item of the language submenu.
const _defaultLanguage = '';

/// Widest the footer text grows before it wraps.
const _footerMaxWidth = 280.0;

/// Items of the lyrics translation menu: the switch, the language submenu,
/// the display style, the service and a footer about the saved translation.
/// Call it from the `build` of the widget that anchors the menu, so the open
/// menu follows [state] and the settings. [context] is the anchor's: the
/// network notice opens on it. [appLang] picks the controller.
List<Widget> lyricsTranslationMenuItems(
  BuildContext context,
  WidgetRef ref,
  LyricsTranslationState state,
  String appLang,
) {
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

  return [
    MenuItemButton(
      closeOnActivate: false,
      onPressed: toggle,
      trailingIcon: ExcludeFocus(
        child: Switch(value: on, onChanged: (_) => toggle()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.lyricsTranslationShow),
          const SizedBox(width: 12),
          Text(
            'T',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
    SubmenuButton(
      menuChildren: [
        RadioMenuButton<String>(
          value: _defaultLanguage,
          groupValue: info.songOverride ?? _defaultLanguage,
          onChanged: (_) => controller.setSongTarget(null),
          child: Text(
            l10n.lyricsTranslationTargetDefault(
              translationLanguageName(l10n, info.defaultTarget),
            ),
          ),
        ),
        for (final language in translationLanguages)
          RadioMenuButton<String>(
            value: language.code,
            groupValue: info.songOverride ?? _defaultLanguage,
            onChanged: (_) => controller.setSongTarget(language.code),
            child: Text(translationLanguageName(l10n, language)),
          ),
      ],
      child: Text(
        l10n.lyricsTranslationTarget(
          translationLanguageName(l10n, info.effective),
        ),
      ),
    ),
    const Divider(height: 1),
    _header(context, l10n.lyricsTranslationDisplayHeader),
    for (final (display, label) in [
      (LyricsTranslationDisplay.underLine, l10n.lyricsTranslationDisplayUnder),
      (LyricsTranslationDisplay.replace, l10n.lyricsTranslationDisplayReplace),
    ])
      RadioMenuButton<LyricsTranslationDisplay>(
        value: display,
        groupValue: prefs.display,
        onChanged: (value) =>
            settings.setTranslation(prefs.copyWith(display: value ?? display)),
        child: Text(label),
      ),
    const Divider(height: 1),
    _header(context, l10n.lyricsTranslationServiceHeader),
    for (final service in LyricsTranslationService.values)
      RadioMenuButton<LyricsTranslationService>(
        value: service,
        groupValue: prefs.service,
        onChanged: (_) => pickService(service),
        child: Text(translationServiceName(service)),
      ),
    ..._footer(context, state, prefs.service, controller),
  ];
}

Widget _header(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  ),
);

/// The note about the translation on screen and the action that goes with
/// it; nothing while translation is off.
List<Widget> _footer(
  BuildContext context,
  LyricsTranslationState state,
  LyricsTranslationService selected,
  LyricsTranslationController controller,
) {
  final l10n = context.l10n;
  final (String? text, String? action, VoidCallback? run) = switch (state) {
    TranslationReady(:final service, :final fromOtherService) => (
      fromOtherService
          ? l10n.lyricsTranslationSavedFrom(translationServiceName(service))
          : l10n.lyricsTranslationSaved,
      fromOtherService
          ? l10n.lyricsTranslationRetranslateWith(
              translationServiceName(selected),
            )
          : l10n.lyricsTranslationRetranslate,
      controller.retranslate,
    ),
    TranslationSameLanguage(:final info) => (
      l10n.lyricsTranslationSameLanguage(
        languageNameInSentence(
          l10n,
          translationLanguageName(l10n, info.effective),
        ),
      ),
      null,
      null,
    ),
    TranslationLoading() => (
      l10n.lyricsTranslationLoading,
      l10n.lyricsTranslationRetranslate,
      null,
    ),
    TranslationFailed(:final kind) => (
      translationFailureMessage(l10n, kind),
      l10n.lyricsTranslationRetry,
      controller.retry,
    ),
    _ => (null, null, null),
  };
  if (text == null) return const [];
  return [
    const Divider(height: 1),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _footerMaxWidth),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ),
    if (action != null)
      // Stays open so the footer shows the new state.
      MenuItemButton(
        closeOnActivate: false,
        onPressed: run,
        child: Text(action),
      ),
  ];
}
