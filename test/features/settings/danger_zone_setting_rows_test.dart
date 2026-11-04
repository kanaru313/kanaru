import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/danger_zone_setting_rows.dart';
import 'package:kanaru/features/settings/settings_busy_tasks.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget testBed({required Widget child, List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('renders Clear listen history and Reset all settings rows', (
    tester,
  ) async {
    await tester.pumpWidget(testBed(child: const DangerZoneSettingRows()));
    await tester.pumpAndSettle();

    expect(find.text('Clear listen history'), findsOneWidget);
    expect(find.text('Reset all settings'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reset'), findsOneWidget);
  });

  testWidgets('cancelling reset all dialog leaves settings unchanged', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          const AppSettings(theme: ThemePreference.dark),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DangerZoneSettingRows()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).theme, ThemePreference.dark);

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Reset all settings?'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Reset all settings?'), findsNothing);
    expect(container.read(settingsProvider).theme, ThemePreference.dark);
  });

  testWidgets(
    'confirming reset all dialog restores defaults and shows snackbar',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            const AppSettings(
              theme: ThemePreference.dark,
              animations: false,
              libraryOnboarded: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DangerZoneSettingRows()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).theme, ThemePreference.dark);
      expect(container.read(settingsProvider).animations, isFalse);

      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Reset all settings?'), findsOneWidget);

      // Tap the dialog's confirm button (Reset)
      final dialogConfirmButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Reset'),
      );
      await tester.tap(dialogConfirmButton);
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).theme, ThemePreference.system);
      expect(container.read(settingsProvider).animations, isTrue);
      expect(container.read(settingsProvider).libraryOnboarded, isTrue);
      expect(
        find.text('All settings have been reset to defaults'),
        findsOneWidget,
      );
    },
  );

  testWidgets('clear button is disabled when task is busy', (tester) async {
    final container = ProviderContainer();
    container
        .read(settingsBusyTasksProvider.notifier)
        .start(SettingsTask.listenHistory);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DangerZoneSettingRows()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final clearBtn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clear'),
    );
    expect(clearBtn.onPressed, isNull);
  });

  testWidgets('reset button is disabled when any task is busy', (tester) async {
    final container = ProviderContainer();
    container
        .read(settingsBusyTasksProvider.notifier)
        .start(SettingsTask.coverCache);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DangerZoneSettingRows()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final resetBtn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reset'),
    );
    expect(resetBtn.onPressed, isNull);
  });

  testWidgets('shows error snackbar when reset fails', (tester) async {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_ThrowingSettingsNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DangerZoneSettingRows()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    final dialogConfirmButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Reset'),
    );
    await tester.tap(dialogConfirmButton);
    await tester.pumpAndSettle();

    expect(find.text('Could not reset settings'), findsOneWidget);
  });
}

class _ThrowingSettingsNotifier extends SettingsNotifier {
  @override
  void resetAllSettings() {
    throw Exception('Disk full');
  }
}
