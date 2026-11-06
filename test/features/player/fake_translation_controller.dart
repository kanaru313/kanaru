import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_controller.dart';
import 'package:kanaru/core/lyrics_translation/lyrics_translation_state.dart';
import 'package:kanaru/core/lyrics_translation/translation_jobs.dart';
import 'package:kanaru/core/lyrics_translation/translation_language.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/player/lyrics/translation/modal/lyrics_translation_modal.dart';
import 'package:kanaru/l10n/app_localizations.dart';

/// The info every scripted state shares: English everywhere.
TranslationTargetInfo fakeTranslationInfo({
  String? songOverride,
  String defaultCode = 'en',
  String hash = 'hash',
}) => TranslationTargetInfo(
  hash: hash,
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

  LyricsTranslationState scripted;
  final bool followSettings;

  int retranslateCalls = 0;
  int retryCalls = 0;
  int cancelRetranslateCalls = 0;
  int dismissFailureCalls = 0;
  final songTargets = <String?>[];

  /// Optional completer returned by [retranslate]; when `null`, [retranslate]
  /// completes immediately with `null`.
  Completer<TranslationJobStatus?>? retranslateCompleter;

  /// Runs inside [retranslate] before it returns, so a test can observe the
  /// state of the world at call time.
  VoidCallback? onRetranslate;

  int get dismissRetranslateFailureCalls => dismissFailureCalls;

  @override
  LyricsTranslationState build() {
    ref.keepAlive();
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
  void emit(LyricsTranslationState next) {
    scripted = next;
    state = next;
  }

  @override
  Future<TranslationJobStatus?> retranslate() {
    retranslateCalls++;
    onRetranslate?.call();
    return retranslateCompleter?.future ?? Future.value(null);
  }

  @override
  void cancelRetranslate() => cancelRetranslateCalls++;

  @override
  void dismissRetranslateFailure() => dismissFailureCalls++;

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

/// Shortcut hint line appended to the translation button's tooltip.
const translationButtonHint = 'Right-click or T: turn translation on or off';

/// Builds the full tooltip of the translation button for [status].
String translationTooltip([String status = 'Lyrics translation']) =>
    '$status\n$translationButtonHint';

/// Default tooltip of the translation button when translation is off.
const translationButtonTooltipOff =
    'Lyrics translation\n$translationButtonHint';

/// Finder for the open [LyricsTranslationModal].
final Finder translationModalFinder = find.byType(LyricsTranslationModal);

/// Pumps enough frames for [LyricsTranslationModal] to finish its route
/// transition without calling `pumpAndSettle` (the modal's marquee labels
/// animate continuously after their start delay).
Future<void> settleTranslationModal(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// Opens the translation modal by tapping the button with [tooltip].
Future<void> openTranslationModal(
  WidgetTester tester, [
  String tooltip = translationButtonTooltipOff,
]) async {
  await tester.tap(find.byTooltip(tooltip));
  await settleTranslationModal(tester);
}
