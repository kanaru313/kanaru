import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/missing_roots_notice.dart';
import 'package:kanaru/core/database/library_browse_missing_roots.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/features/player/now_playing/now_playing_open_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../features/library/browse_test_data.dart';
import '../features/library/library_test_harness.dart';

void main() {
  /// Pumps the app with [roots] in the library, of which only [existing]
  /// are folders; [checked] counts the folder checks.
  Future<LibraryHarness> pumpWith(
    WidgetTester tester, {
    required List<String> roots,
    Set<String> existing = const {},
    List<String>? checked,
    bool hasDatabase = true,
    List<Override> overrides = const [],
  }) async {
    final h = LibraryHarness(
      hasDatabase: hasDatabase,
      rootIsDirectory: (path) async {
        checked?.add(path);
        return existing.contains(path);
      },
      overrides: overrides,
    );
    if (hasDatabase && roots.isNotEmpty) {
      await tester.runAsync(() => h.db.addRoots(roots, now: 1));
    }
    await h.pump(tester, hasRoots: roots.isNotEmpty);
    // The database answers in real time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('one missing folder is named', (tester) async {
    await pumpWith(tester, roots: ['/music', '/gone'], existing: {'/music'});

    expect(find.text('Music folder not found: /gone'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Settings'), findsOneWidget);
  });

  testWidgets('several missing folders are counted', (tester) async {
    await pumpWith(tester, roots: ['/a', '/b', '/c'], existing: {'/c'});

    expect(find.text('2 music folders not found'), findsOneWidget);
  });

  testWidgets('no notice when every folder exists', (tester) async {
    await pumpWith(tester, roots: ['/a', '/b'], existing: {'/a', '/b'});

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no notice and no check without folders', (tester) async {
    final checked = <String>[];
    await pumpWith(tester, roots: [], checked: checked);

    expect(find.byType(SnackBar), findsNothing);
    expect(checked, isEmpty);
  });

  testWidgets('no notice without a library database', (tester) async {
    final checked = <String>[];
    await pumpWith(
      tester,
      roots: ['/gone'],
      checked: checked,
      hasDatabase: false,
    );

    expect(find.byType(SnackBar), findsNothing);
    expect(checked, isEmpty);
  });

  testWidgets('also shown when rescan on startup is off', (tester) async {
    await pumpWith(
      tester,
      roots: ['/gone'],
      overrides: [
        initialSettingsProvider.overrideWithValue(
          const AppSettings(rescanOnStartup: false),
        ),
      ],
    );

    expect(find.text('Music folder not found: /gone'), findsOneWidget);
  });

  testWidgets('the Settings action opens the settings page', (tester) async {
    final h = await pumpWith(tester, roots: ['/gone']);
    expect(location(h), isNot('/settings'));

    await tester.tap(find.widgetWithText(SnackBarAction, 'Settings'));
    await tester.pumpAndSettle();

    expect(location(h), '/settings');
  });

  testWidgets('moving around does not show it again', (tester) async {
    final checked = <String>[];
    final h = await pumpWith(tester, roots: ['/gone'], checked: checked);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    for (final path in ['/albums', '/artists', '/settings', '/']) {
      goTo(tester, h, path);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
    h.container.read(nowPlayingOpenProvider.notifier).close();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(checked, ['/gone'], reason: 'checked once');
  });

  testWidgets('a notice built again in the same launch stays quiet', (
    tester,
  ) async {
    final db = LibraryDatabase(NativeDatabase.memory());
    await tester.runAsync(() => db.addRoots(['/gone'], now: 1));
    final checked = <String>[];
    final container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        rootIsDirectoryProvider.overrideWithValue((path) async {
          checked.add(path);
          return false;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(db.close);
    });
    Widget app(bool shown) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: shown
            ? const MissingRootsNotice(child: Scaffold())
            : const Scaffold(),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(app(true));
    await settle();
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
    await settle();

    expect(checked, ['/gone'], reason: 'checked once per launch');
  });

  testWidgets('roots that cannot be read say nothing and are not retried', (
    tester,
  ) async {
    final db = _BrokenRootsDatabase();
    final container = ProviderContainer(
      overrides: [libraryDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const MissingRootsNotice(child: Scaffold()),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
    expect(container.read(missingRootsCheckedProvider), isTrue);
  });

  testWidgets('marked as checked before the roots arrive', (tester) async {
    final gate = Completer<List<LibraryRoot>>();
    final db = _GatedRootsDatabase(gate.future);
    final checked = <String>[];
    final container = ProviderContainer(
      overrides: [
        libraryDatabaseProvider.overrideWithValue(db),
        rootIsDirectoryProvider.overrideWithValue((path) async {
          checked.add(path);
          return false;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await tester.runAsync(db.close);
    });
    // Two notices start their check while the first read is still pending.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: Column(
              children: [
                MissingRootsNotice(child: SizedBox()),
                MissingRootsNotice(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    expect(db.reads, 1, reason: 'the second notice found the flag set');

    gate.complete([
      LibraryRoot(id: 1, path: '/gone', addedAt: 1, lastScanAt: null),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(checked, ['/gone']);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

/// A database whose root list cannot be read.
class _BrokenRootsDatabase extends LibraryDatabase {
  _BrokenRootsDatabase() : super(NativeDatabase.memory());

  @override
  Future<List<LibraryRoot>> roots() => Future.error(StateError('no roots'));
}

/// A database that holds back its root list until [gate] completes.
class _GatedRootsDatabase extends LibraryDatabase {
  _GatedRootsDatabase(this.gate) : super(NativeDatabase.memory());

  final Future<List<LibraryRoot>> gate;
  int reads = 0;

  @override
  Future<List<LibraryRoot>> roots() {
    reads++;
    return gate;
  }
}
