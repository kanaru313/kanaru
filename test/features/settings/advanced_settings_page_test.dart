import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/features/settings/advanced_settings_page.dart';
import 'package:kanaru/features/settings/settings_section.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/open_external.dart';
import 'package:kanaru/shared/settings_routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

Future<void> _pump(
  WidgetTester tester, {
  SettingsAnchor? focus,
  Size size = const Size(1280, 4000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        openExternalProvider.overrideWithValue((_) async => true),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: AdvancedSettingsPage(focus: focus),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows all 4 section titles in order', (tester) async {
    await _pump(tester);

    expect(find.text('Advanced'), findsOneWidget);

    final expectedSections = [
      'Audio engine',
      'Privacy & network',
      'Diagnostics',
      'Danger zone',
    ];

    for (final title in expectedSections) {
      expect(find.text(title), findsOneWidget);
    }

    final tops = [
      for (final title in expectedSections)
        tester
            .getTopLeft(
              find.byWidgetPredicate(
                (w) => w is SettingsSection && w.title == title,
              ),
            )
            .dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('contains key controls across all groups', (tester) async {
    await _pump(tester);

    // Audio Engine
    expect(find.text('Output device'), findsOneWidget);
    expect(find.text('ReplayGain'), findsOneWidget);
    expect(find.text('Gapless playback'), findsOneWidget);

    // Privacy & Network
    expect(find.text('Confirm before uninstalling plugins'), findsOneWidget);

    // Diagnostics
    expect(find.text('Log files'), findsOneWidget);

    // Danger Zone
    expect(find.text('Clear listen history'), findsOneWidget);
    expect(find.text('Reset all settings'), findsOneWidget);
  });
}
