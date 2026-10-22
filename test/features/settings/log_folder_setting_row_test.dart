import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/log_folder_setting_row.dart';
import 'package:kanaru/features/settings/open_external.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String? directory,
  required Future<bool> Function(String) open,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      logDirectoryProvider.overrideWithValue(directory),
      openExternalProvider.overrideWithValue(open),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: Scaffold(body: LogFolderSettingRow()),
    ),
  ),
);

void main() {
  testWidgets('the button opens the log folder', (tester) async {
    final opened = <String>[];
    await _pump(
      tester,
      directory: '/home/me/.cache/kanaru/logs',
      open: (target) async {
        opened.add(target);
        return true;
      },
    );

    expect(find.text('Log files'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(opened, ['/home/me/.cache/kanaru/logs']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed open says so', (tester) async {
    await _pump(tester, directory: '/logs', open: (_) async => false);

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.text("Couldn't open /logs"), findsOneWidget);
  });

  testWidgets('without a log folder the button is off and says why', (
    tester,
  ) async {
    await _pump(tester, directory: null, open: (_) async => true);

    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Open'),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text('Kanaru has no folder for log files on this system.'),
      findsOneWidget,
    );
  });
}
