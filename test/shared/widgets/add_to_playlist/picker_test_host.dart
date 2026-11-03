import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/library_startup.dart';
import 'package:kanaru/core/database/playlist_queries.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:kanaru/shared/widgets/add_to_playlist/add_to_playlist_flow.dart';
import 'package:material_ui/material_ui.dart';

/// The picker dialog (not the dialogs it opens above itself).
Finder get picker => find.byKey(const ValueKey('playlist-picker'));

Finder inPicker(Finder of) => find.descendant(of: picker, matching: of);

Finder get addButton => inPicker(find.byType(FilledButton));

/// A button "Open" that runs `addTracksToPlaylistWith` over an in-memory
/// library holding the playlists [seed] (name to paths), newest last seeded
/// first in the list.
class PickerHost {
  PickerHost(this.db);

  final LibraryDatabase db;

  Future<List<String>> Function() readPaths = () async => ['/m/1', '/m/2'];
  int? excludePlaylistId;
  String? suggestedName;

  Future<int> idOf(WidgetTester tester, String name) async {
    final rows = await tester.runAsync(() => db.watchPlaylistSummaries().first);
    return rows!.firstWhere((p) => p.name == name).id;
  }

  Future<List<String>> pathsIn(WidgetTester tester, String name) async {
    final id = await idOf(tester, name);
    final page = await tester.runAsync(() => db.playlistPage(id));
    return [for (final e in page!.entries) e.path];
  }

  Future<List<String>> playlistNames(WidgetTester tester) async {
    final rows = await tester.runAsync(() => db.watchPlaylistSummaries().first);
    return [for (final p in rows!) p.name];
  }
}

/// Mounts the host and returns it; [seed] playlists are created first.
Future<PickerHost> pumpPickerHost(
  WidgetTester tester, {
  Map<String, List<String>> seed = const {},
  void Function(PickerHost host)? configure,
}) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = LibraryDatabase(NativeDatabase.memory());
  var now = 1;
  for (final MapEntry(:key, :value) in seed.entries) {
    await tester.runAsync(
      () => db.createPlaylist(key, now: now++, paths: value),
    );
  }
  final host = PickerHost(db);
  configure?.call(host);
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
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => addTracksToPlaylistWith(
                db: db,
                messenger: ScaffoldMessenger.of(context),
                l10n: context.l10n,
                dialogContext: Navigator.of(
                  context,
                  rootNavigator: true,
                ).context,
                readPaths: () => host.readPaths(),
                label: 'Road album',
                excludePlaylistId: host.excludePlaylistId,
                suggestedName: host.suggestedName,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  return host;
}

/// Lets drift streams and writes finish.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await settle(tester);
}

/// Taps "New playlist…", types [name] and presses Create.
Future<void> nameNew(WidgetTester tester, String name) async {
  await tester.tap(inPicker(find.text('New playlist…')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.widgetWithText(FilledButton, 'Create'));
  await tester.pumpAndSettle();
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pumpAndSettle();
}

/// Ticks (or unticks) the playlist row named [name].
Future<void> tick(WidgetTester tester, String name) async {
  await tester.tap(inPicker(find.text(name)));
  await tester.pumpAndSettle();
}
