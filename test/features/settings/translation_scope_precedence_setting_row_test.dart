import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics_translation/translation_scope.dart';
import 'package:kanaru/core/lyrics_translation/translation_service.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/translation_scope_precedence_setting_row.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/widgets/selection_row.dart';
import 'package:material_ui/material_ui.dart';

final _plugin = TranslationServiceId.tryParse('plugin-abc123def456')!;

/// The picker animates in and out; advance past it without waiting for idle.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    TranslationScopePrecedence precedence =
        TranslationScopePrecedence.replaceAll,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(
            translation: TranslationPrefs(
              show: true,
              service: _plugin,
              noticeAcknowledged: {_plugin},
              allChosenAt: 77,
              scopePrecedence: precedence,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TranslationScopePrecedenceSettingRow()),
        ),
      ),
    );
    await tester.pump();
  }

  TranslationPrefs prefs() => container.read(settingsProvider).translation;

  testWidgets('default is "Change every song" with the caption under it', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.text('When changing the service for all songs'),
      findsOneWidget,
    );
    expect(find.text('Change every song'), findsOneWidget);
    expect(find.byIcon(AppIcons.expandMore), findsOneWidget);
    expect(
      find.text(
        'The queue follows the same rule. Saved translations still show as '
        'before; nothing is translated again automatically.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the picker marks the current choice, with no radio', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Change every song'));
    await settle(tester);

    expect(find.byType(Radio<TranslationScopePrecedence>), findsNothing);
    final rows = tester
        .widgetList<SelectionRow>(find.byType(SelectionRow))
        .toList();
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.selected), hasLength(1));
    expect(
      tester
          .widget<SelectionRow>(
            find.widgetWithText(SelectionRow, 'Change every song'),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<SelectionRow>(
            find.widgetWithText(SelectionRow, 'Keep songs set individually'),
          )
          .selected,
      isFalse,
    );
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    expect(
      find.text('Every song changes, even songs you set to “This song”.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Songs you set to “This song” stay as they are. Only the others change.',
      ),
      findsOneWidget,
    );
    expect(find.text('Keep songs set individually'), findsOneWidget);
  });

  testWidgets('picking Keep saves it and leaves the rest of the prefs', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Change every song'));
    await settle(tester);
    await tester.tap(find.text('Keep songs set individually'));
    await settle(tester);

    expect(prefs().scopePrecedence, TranslationScopePrecedence.keepCustom);
    expect(prefs().allChosenAt, 77);
    expect(prefs().noticeAcknowledged, {_plugin});
    expect(prefs().service, _plugin);
    expect(prefs().show, isTrue);
    expect(find.text('Keep songs set individually'), findsOneWidget);
  });

  testWidgets('closing the picker without a choice writes nothing', (
    tester,
  ) async {
    await pump(tester);
    final before = prefs();
    await tester.tap(find.text('Change every song'));
    await settle(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(prefs(), before);

    // Picking the value already set writes nothing either.
    await tester.tap(find.text('Change every song'));
    await settle(tester);
    await tester.tap(find.widgetWithText(SelectionRow, 'Change every song'));
    await settle(tester);
    expect(prefs(), before);
  });

  testWidgets('shows the saved Keep choice in Vietnamese', (tester) async {
    await pump(
      tester,
      locale: const Locale('vi'),
      precedence: TranslationScopePrecedence.keepCustom,
    );
    expect(find.text('Khi đổi dịch vụ cho mọi bài'), findsOneWidget);
    expect(find.text('Giữ bài đã chỉnh riêng'), findsOneWidget);
  });
}
