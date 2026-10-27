import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/app_localizations.dart';

/// The info every scripted state shares: English everywhere.
TranslationTargetInfo fakeTranslationInfo({
  String? songOverride,
  String defaultCode = 'en',
}) => TranslationTargetInfo(
  hash: 'hash',
  effective: translationLanguageFor(songOverride ?? defaultCode)!,
  songOverride: songOverride,
  defaultTarget: translationLanguageFor(defaultCode)!,
);

/// A controller that answers with a scripted state and records the calls the
/// menu makes. With [followSettings] the state is [scripted] while the
/// settings show translation, and "off" otherwise, so the open menu can be
/// seen reacting to its own switch.
class FakeTranslationController extends LyricsTranslationController {
  FakeTranslationController(this.scripted, {this.followSettings = false})
    : super('en');

  final LyricsTranslationState scripted;
  final bool followSettings;

  int retranslateCalls = 0;
  int retryCalls = 0;
  final songTargets = <String?>[];

  @override
  LyricsTranslationState build() {
    if (!followSettings) return scripted;
    final on = ref.watch(
      settingsProvider.select(
        (s) => s.translation.show && !s.translation.needsNotice,
      ),
    );
    final info = fakeTranslationInfo();
    return on ? scripted : TranslationOff(info);
  }

  /// Moves to [next], as a real state change would.
  void emit(LyricsTranslationState next) => state = next;

  @override
  Future<void> retranslate() async => retranslateCalls++;

  @override
  Future<void> retry() async => retryCalls++;

  @override
  Future<void> setSongTarget(String? code) async => songTargets.add(code);
}

/// Replaces the controller of the app language `en` with [fake].
Override fakeTranslationOverride(FakeTranslationController fake) =>
    lyricsTranslationProvider.overrideWith2((_) => fake);

/// Everything a translation widget needs around it.
Widget translationApp(
  ProviderContainer container,
  Widget child, {
  Locale locale = const Locale('en'),
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

/// Opens the anchor button's menu by its tooltip.
Future<void> openMenuByTooltip(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}
