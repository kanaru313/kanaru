import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/lyrics/online/lyrics_fetch_exception.dart';
import 'package:kanaru/core/lyrics/plugins/plugin_log_paths.dart';
import 'package:kanaru/features/player/lyrics/lyrics_error_banner.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/show_in_file_manager.dart';
import 'package:material_ui/material_ui.dart';

const _plugin = 'plugin-aaaaaaaaaaaa';

void main() {
  late Directory logDir;
  final opened = <String>[];
  var openResult = true;

  setUp(() {
    logDir = Directory.systemTemp.createTempSync('kanaru-banner-logs');
    opened.clear();
    openResult = true;
    addTearDown(() => logDir.deleteSync(recursive: true));
  });

  Future<void> pump(
    WidgetTester tester, {
    required String name,
    String? logProviderId,
    LyricsFetchKind? failure = LyricsFetchKind.invalidResponse,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        lyricsPluginLogDirProvider.overrideWithValue(logDir),
        showInFileManagerProvider.overrideWithValue((path) async {
          opened.add(path);
          return openResult;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LyricsErrorBanner(
            providerName: name,
            logProviderId: logProviderId,
            canRetry: false,
            failure: failure,
          ),
        ),
      ),
    ),
  );

  void writeLog() =>
      File('${logDir.path}/$_plugin.jsonl').writeAsStringSync('{}\n');

  testWidgets('a plugin failure names the plugin and shows View log', (
    tester,
  ) async {
    writeLog();
    await pump(tester, name: 'NetEase', logProviderId: _plugin);

    expect(
      find.text('NetEase answered but Kanaru could not read it'),
      findsOneWidget,
    );
    expect(find.text('View log'), findsOneWidget);

    await tester.tap(find.text('View log'));
    await tester.pump();
    expect(opened, ['${logDir.path}/$_plugin.jsonl']);
  });

  testWidgets('View log is hidden when the plugin has not logged yet', (
    tester,
  ) async {
    await pump(tester, name: 'NetEase', logProviderId: _plugin);

    expect(
      find.text('NetEase answered but Kanaru could not read it'),
      findsOneWidget,
    );
    expect(find.text('View log'), findsNothing);
  });

  testWidgets('View log is hidden for LRCLIB', (tester) async {
    writeLog();
    await pump(tester, name: 'LRCLIB', logProviderId: 'lrclib');

    expect(find.text('View log'), findsNothing);
  });

  testWidgets('View log is hidden when the failed source is unknown', (
    tester,
  ) async {
    writeLog();
    await pump(tester, name: 'NetEase, LRCLIB');

    expect(find.text('View log'), findsNothing);
  });

  testWidgets('a file manager that cannot open it says so', (tester) async {
    writeLog();
    openResult = false;
    await pump(tester, name: 'NetEase', logProviderId: _plugin);

    await tester.tap(find.text('View log'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("Couldn't open"), findsOneWidget);
  });
}
