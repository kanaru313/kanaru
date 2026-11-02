import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_database.dart';
import 'package:kanaru/core/database/playlist_rows.dart';
import 'package:kanaru/core/database/playlist_writes.dart';
import 'package:kanaru/features/playlists/playlist_edit_flow.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

const _failure = "Couldn't save the playlist. See the log for details.";
final _nameField = find.byKey(const ValueKey('playlist-edit-name'));
final _descriptionField = find.byKey(
  const ValueKey('playlist-edit-description'),
);
final _save = find.widgetWithText(FilledButton, 'Save');

void main() {
  late LibraryDatabase db;
  late GlobalKey<ScaffoldMessengerState> modalKey;
  late GlobalKey<ScaffoldMessengerState> openerKey;
  late BuildContext rootContext;
  late PlaylistSummary playlist;
  final showModal = ValueNotifier<bool>(true);

  /// An app with an opener messenger and, beside it, a modal messenger.
  Future<void> pump(WidgetTester tester, {bool withModal = true}) async {
    showModal.value = true;
    modalKey = GlobalKey();
    openerKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScaffoldMessenger(
            key: openerKey,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  rootContext = context;
                  return ValueListenableBuilder(
                    valueListenable: showModal,
                    builder: (context, shown, _) => shown && withModal
                        ? ScaffoldMessenger(
                            key: modalKey,
                            child: const Scaffold(),
                          )
                        : const SizedBox(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> setUpPlaylist(WidgetTester tester) async {
    db = LibraryDatabase(NativeDatabase.memory());
    final id = await tester.runAsync(() => db.createPlaylist('Old', now: 1));
    playlist = PlaylistSummary(
      id: id!,
      name: 'Old',
      createdAt: 1,
      entryCount: 0,
    );
  }

  Future<void> edit(
    WidgetTester tester, {
    String? name,
    String? description,
    bool dropModalBeforeSave = false,
  }) async {
    final messenger = modalKey.currentState;
    final future = editPlaylistWith(
      db: db,
      modalMessenger: messenger,
      openerMessenger: openerKey.currentState,
      l10n: AppLocalizations.of(rootContext),
      dialogContext: rootContext,
      playlist: playlist,
      coverKeys: const [],
    );
    await tester.pumpAndSettle();
    if (name != null) await tester.enterText(_nameField, name);
    if (description != null) {
      await tester.enterText(_descriptionField, description);
    }
    if (dropModalBeforeSave) {
      showModal.value = false;
      await tester.pump();
      expect(messenger!.mounted, isFalse);
    }
    await tester.tap(_save);
    await tester.pump();
    await tester.runAsync(() => future);
    await tester.pumpAndSettle();
  }

  Future<Playlist> row(WidgetTester tester) async {
    final rows = await tester.runAsync(() => db.select(db.playlists).get());
    return rows!.firstWhere((r) => r.id == playlist.id);
  }

  testWidgets('Save writes name and description', (tester) async {
    await setUpPlaylist(tester);
    addTearDown(db.close);
    await pump(tester);
    await edit(tester, name: 'New', description: 'About');
    final saved = await row(tester);
    expect((saved.name, saved.description), ('New', 'About'));
  });

  testWidgets('saving unchanged values changes nothing', (tester) async {
    await setUpPlaylist(tester);
    addTearDown(db.close);
    await pump(tester);
    await edit(tester);
    final saved = await row(tester);
    expect((saved.name, saved.description), ('Old', ''));
    expect(find.text(_failure), findsNothing);
  });

  testWidgets('a failed save says so on the modal messenger', (tester) async {
    await setUpPlaylist(tester);
    await pump(tester);
    // Closed on purpose: every write now throws.
    await tester.runAsync(db.close);
    await edit(tester, name: 'New');
    expect(
      find.descendant(
        of: find.byWidget(modalKey.currentWidget!),
        matching: find.text(_failure),
      ),
      findsOneWidget,
    );
    // Nowhere else: not on the opener messenger either.
    expect(find.text(_failure), findsOneWidget);
  });

  testWidgets('a failed save with the modal gone lands on the opener', (
    tester,
  ) async {
    await setUpPlaylist(tester);
    await pump(tester);
    await tester.runAsync(db.close);
    await edit(tester, name: 'New', dropModalBeforeSave: true);
    expect(find.text(_failure), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save falls back to the opener messenger', (
    tester,
  ) async {
    await setUpPlaylist(tester);
    // No modal: its messenger is null, so the opener's one is used.
    await pump(tester, withModal: false);
    await tester.runAsync(db.close);
    await edit(tester, name: 'New');
    expect(find.text(_failure), findsOneWidget);
  });
}
