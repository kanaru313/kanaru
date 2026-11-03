import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_write.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/m3u/m3u_export_flow.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory tmp;
  late String root;
  late String? picked;
  late List<String> suggested;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kanaru-shared-m3u-export');
    root = await tmp.resolveSymbolicLinks();
    picked = null;
    suggested = [];
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<void> pumpHost(
    WidgetTester tester, {
    required String name,
    required M3uPathStyle style,
    required Future<List<M3uExportEntry>?> Function() readEntries,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => exportM3uWith(
                save: (suggestedName) async {
                  suggested.add(suggestedName);
                  return picked;
                },
                messenger: ScaffoldMessenger.of(context),
                l10n: context.l10n,
                navigator: Navigator.of(context, rootNavigator: true),
                name: name,
                style: style,
                readEntries: readEntries,
              ),
              child: const Text('Export'),
            ),
          ),
        ),
      ),
    );
  }

  /// Taps Export and lets file I/O finish until [until] shows.
  Future<void> run(WidgetTester tester, Finder until) async {
    await tester.tap(find.text('Export'));
    for (var i = 0; i < 100 && until.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<String?> read(WidgetTester tester, String path) =>
      tester.runAsync<String?>(() async {
        final file = File(path);
        return await file.exists() ? file.readAsString() : null;
      });

  List<M3uExportEntry> entries() => [
    M3uExportEntry(
      path: '$root/music/a.flac',
      title: 'a',
      artist: 'Ann',
      durationMs: 1000,
    ),
  ];

  testWidgets('unreadable source shows the failure and writes nothing', (
    tester,
  ) async {
    picked = '$root/out';
    await pumpHost(
      tester,
      name: 'List',
      style: M3uPathStyle.absolute,
      readEntries: () async => null,
    );

    await run(tester, find.byType(SnackBar));

    expect(find.textContaining("Couldn't save"), findsOneWidget);
    expect(await read(tester, '$root/out.m3u8'), isNull);
  });

  testWidgets('the name is cleaned and the path style is honored', (
    tester,
  ) async {
    picked = '$root/lists/out';
    await tester.runAsync(() => Directory('$root/lists').create());
    await pumpHost(
      tester,
      name: '  Fri\u0007day\u202e  ',
      style: M3uPathStyle.relative,
      readEntries: () async => entries(),
    );

    await run(tester, find.byType(SnackBar));

    expect(suggested, ['Fri day.m3u8']);
    expect(
      await read(tester, '$root/lists/out.m3u8'),
      '#EXTM3U\n#EXTINF:1,Ann - a\n../music/a.flac\n',
    );
    expect(find.text('Saved 1 song to out.m3u8'), findsOneWidget);
  });

  testWidgets('an empty name falls back to the default playlist name', (
    tester,
  ) async {
    await pumpHost(
      tester,
      name: ' \u0007 ',
      style: M3uPathStyle.absolute,
      readEntries: () async => entries(),
    );

    await run(tester, find.byType(SnackBar));

    expect(suggested, ['New playlist.m3u8']);
  });

  testWidgets('absolute style writes full paths', (tester) async {
    picked = '$root/abs.m3u';
    await pumpHost(
      tester,
      name: 'List',
      style: M3uPathStyle.absolute,
      readEntries: () async => entries(),
    );

    await run(tester, find.byType(SnackBar));

    expect(
      await read(tester, '$root/abs.m3u'),
      '#EXTM3U\n#EXTINF:1,Ann - a\n$root/music/a.flac\n',
    );
  });

  testWidgets('an existing file asks first; cancel keeps it', (tester) async {
    picked = '$root/keep.m3u8';
    await tester.runAsync(() => File(picked!).writeAsString('old'));
    var reads = 0;
    await pumpHost(
      tester,
      name: 'List',
      style: M3uPathStyle.absolute,
      readEntries: () async {
        reads++;
        return entries();
      },
    );

    await run(tester, find.byType(AlertDialog));
    expect(find.text('Replace keep.m3u8?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(reads, 0);
    expect(await read(tester, picked!), 'old');
  });

  testWidgets('confirming the overwrite writes the file', (tester) async {
    picked = '$root/over.m3u8';
    await tester.runAsync(() => File(picked!).writeAsString('old'));
    await pumpHost(
      tester,
      name: 'List',
      style: M3uPathStyle.absolute,
      readEntries: () async => entries(),
    );

    await run(tester, find.byType(AlertDialog));
    await tester.tap(find.text('Replace'));
    await run(tester, find.byType(SnackBar));

    expect(await read(tester, picked!), contains('a.flac'));
  });
}
