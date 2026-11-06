import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/lyrics_plugin_spec.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/lyrics_plugins/plugin_uninstall_dialog.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/lyrics_sources/lyrics_sources_harness.dart';

void main() {
  Future<void> open(WidgetTester tester, PluginKind kind) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmPluginUninstall(
              context,
              testRecord(idA, pluginKind: kind),
              (storageBytes: 0, foundCount: 2, textBytes: 10),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a translate plugin says its translations stay', (tester) async {
    await open(tester, PluginKind.translate);
    expect(
      find.textContaining(en.pluginUninstallKeepTranslations),
      findsOneWidget,
    );
    expect(find.textContaining(en.pluginUninstallKeepLrc), findsNothing);
    expect(find.textContaining(en.pluginUninstallKeepPinned), findsNothing);
    expect(find.textContaining(en.pluginUninstallKeepLyrics(2)), findsNothing);
  });

  testWidgets('a lyrics plugin keeps the lyrics lines', (tester) async {
    await open(tester, PluginKind.lyrics);
    expect(
      find.textContaining(en.pluginUninstallKeepLyrics(2)),
      findsOneWidget,
    );
    expect(find.textContaining(en.pluginUninstallKeepLrc), findsOneWidget);
    expect(
      find.textContaining(en.pluginUninstallKeepTranslations),
      findsNothing,
    );
  });

  testWidgets('a source plugin says only that the library is not affected', (
    tester,
  ) async {
    await open(tester, PluginKind.source);
    expect(
      find.textContaining(en.pluginUninstallKeepNothingSource),
      findsOneWidget,
    );
    expect(find.textContaining(en.pluginUninstallKeepLrc), findsNothing);
    expect(find.textContaining(en.pluginUninstallKeepPinned), findsNothing);
    expect(find.textContaining(en.pluginUninstallKeepLyrics(2)), findsNothing);
    expect(
      find.textContaining(en.pluginUninstallKeepTranslations),
      findsNothing,
    );
  });
}
