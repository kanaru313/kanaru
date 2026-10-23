import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/indexer/indexer_state.dart';
import 'package:kanaru/features/settings/cover_cache_setting_rows.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/indexer/scripted_indexer.dart';

void main() {
  late Directory cache;
  late String covers;
  late File thumbnail;
  late ScriptedIndexer indexer;
  late ProviderContainer container;
  LibraryDatabase? db;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('kanaru-cover-row');
    covers = '${cache.path}/covers/512';
    thumbnail = File('$covers/aa/${'a' * 64}.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    // Older than the click, as a real cached thumbnail is.
    thumbnail.setLastModifiedSync(
      DateTime.now().subtract(const Duration(hours: 1)),
    );
  });
  tearDown(() async {
    await db?.close();
    db = null;
    cache.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {bool withDatabase = true}) async {
    db = withDatabase ? LibraryDatabase(NativeDatabase.memory()) : null;
    indexer = ScriptedIndexer();
    container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        coverCacheDirectoryProvider.overrideWithValue(covers),
        libraryIndexerProvider.overrideWith(() => indexer),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: CoverCacheSettingRows()),
        ),
      ),
    );
  }

  final button = find.widgetWithText(FilledButton, 'Clear');

  bool enabled(WidgetTester tester) =>
      tester.widget<FilledButton>(button).onPressed != null;

  Future<void> confirm(WidgetTester tester, {required bool yes}) async {
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      yes
          ? find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(FilledButton, 'Clear'),
            )
          : find.text('Cancel'),
    );
    // The delete runs in an isolate: real time for it.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cancelling the dialog deletes nothing', (tester) async {
    await pump(tester);
    await confirm(tester, yes: false);

    expect(thumbnail.existsSync(), isTrue);
    expect(indexer.scans, 0);
  });

  testWidgets('confirming deletes the thumbnails and rescans', (tester) async {
    await pump(tester);
    await confirm(tester, yes: true);

    expect(thumbnail.existsSync(), isFalse);
    expect(indexer.scans, 1);
    expect(find.text('Deleted 1 cover. A rescan makes them again.'), findsOne);
  });

  testWidgets('the button is off while a scan or the cover pass runs', (
    tester,
  ) async {
    await pump(tester);
    expect(enabled(tester), isTrue);

    indexer.emit(
      const IndexerScanning(phase: ScanPhase.discovering, rootPath: '/m'),
    );
    await tester.pump();
    expect(enabled(tester), isFalse);

    indexer.emit(const IndexerIdle());
    container.read(coverPassProvider.notifier).report(1, 10);
    await tester.pump();
    expect(enabled(tester), isFalse);

    container.read(coverPassProvider.notifier).finish();
    await tester.pump();
    expect(enabled(tester), isTrue);
  });

  testWidgets('the button is off without a library', (tester) async {
    await pump(tester, withDatabase: false);
    expect(enabled(tester), isFalse);
  });
}
