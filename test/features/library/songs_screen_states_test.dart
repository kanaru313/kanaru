import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/router.dart';
import 'package:kanaru/core/indexer/library_roots_controller.dart';
import 'package:kanaru/features/library/songs/songs_list_provider.dart';
import 'package:material_ui/material_ui.dart';

import 'library_test_harness.dart';

class _ThrowingRootsController implements LibraryRootsController {
  @override
  Future<AddRootsResult> addRoots(List<String> paths) =>
      Future.error(StateError('boom'));

  @override
  Future<RootChangeResult> removeRoot(int id) => throw UnimplementedError();

  @override
  Future<RootChangeResult> replaceRoot(int id, String newPath) =>
      throw UnimplementedError();
}

void main() {
  Future<void> openSongs(
    WidgetTester tester,
    LibraryHarness h, {
    required String folder,
  }) async {
    await tester.runAsync(() => h.db.addRoots([folder], now: 1));
    await h.pump(tester, hasRoots: true);
    h.container.read(routerProvider).go('/songs');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows a progress indicator, not the empty state, while loading',
    (tester) async {
      final never = StreamController<SongIds>();
      addTearDown(never.close);
      final h = LibraryHarness(
        overrides: [songIdsProvider.overrideWith((ref) => never.stream)],
      );
      await tester.runAsync(() => h.db.addRoots([h.folder('music')], now: 1));
      await h.pump(tester, hasRoots: true);
      h.container.read(routerProvider).go('/songs');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No songs found'), findsNothing);
    },
  );

  testWidgets('a failing songs stream says the library is unavailable', (
    tester,
  ) async {
    final h = LibraryHarness(
      overrides: [
        songIdsProvider.overrideWith(
          (ref) => Stream<SongIds>.error(StateError('db gone')),
        ),
      ],
    );
    await openSongs(tester, h, folder: h.folder('music'));

    expect(find.text('Couldn\'t open the library'), findsOneWidget);
    expect(find.text('No songs found'), findsNothing);
  });

  testWidgets('an unexpected error while adding a folder is reported', (
    tester,
  ) async {
    final h = LibraryHarness(rootsController: _ThrowingRootsController());
    h.picks.add(h.folder('music'));
    await h.pump(tester);
    h.container.read(routerProvider).go('/songs');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose music folder'));
    await settleIo(tester, h);

    expect(
      find.text('Something went wrong. See the log for details.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Choose music folder'),
          )
          .onPressed,
      isNotNull,
      reason: 'the button works again',
    );
  });

  testWidgets('a second click while the picker is open is ignored', (
    tester,
  ) async {
    var opened = 0;
    final release = Completer<String?>();
    final h = LibraryHarness(
      picker: () {
        opened++;
        return release.future;
      },
    );
    await h.pump(tester);
    h.container.read(routerProvider).go('/songs');
    await tester.pumpAndSettle();

    final button = find.text('Choose music folder');
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();

    expect(opened, 1);
    release.complete(null);
    await tester.pumpAndSettle();
  });
}
