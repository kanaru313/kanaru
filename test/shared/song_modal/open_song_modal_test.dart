import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/database/library_rows.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/icons/app_icons.dart';
import 'package:kanaru/shared/song_modal/open_song_modal.dart';
import 'package:kanaru/shared/song_modal/song_modal_extras.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_route.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

import 'song_modal_test_support.dart' hide openSongModal;

const _song = TrackListItem(id: 1, path: '/m/1.flac', title: 'one');

/// A button that opens the modal of [_song] with [extra] actions.
Future<void> _pump(
  WidgetTester tester, {
  List<ContextModalAction> extra = const [],
  ValueChanged<QueueAction>? onQueue,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => openSongModal(
              context,
              ref,
              song: _song,
              onQueueAction: onQueue ?? (_) {},
              extras: SongModalExtras(actions: extra),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('opens on the very next frame, named Song options', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Go to artist'), findsOneWidget);
    expect(find.bySemanticsLabel('Song options'), findsWidgets);
  });

  testWidgets('extra actions come first and close the modal when told to', (
    tester,
  ) async {
    var called = 0;
    await _pump(
      tester,
      extra: [
        ContextModalAction(
          id: 'dummy',
          icon: AppIcons.remove,
          label: 'Dummy action',
          onTap: (nav) {
            called++;
            nav.close();
          },
        ),
      ],
    );

    await tester.tap(find.text('open'));
    await settleSongModal(tester);
    final dummy = tester.getTopLeft(modalAction('dummy')).dy;
    final firstLink = tester.getTopLeft(modalAction('artist')).dy;
    expect(dummy, lessThan(firstLink));

    await tapModalAction(tester, 'Dummy action');

    expect(called, 1);
    expect(find.text('Dummy action'), findsNothing);
  });

  testWidgets('Advanced opens a page and Back returns to the actions', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('open'));
    await settleSongModal(tester);

    await tapModalAction(tester, 'Advanced');
    expect(find.text('Delete file from disk'), findsOneWidget);
    expect(find.text('Go to artist'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await settleSongModal(tester);
    expect(find.text('Go to artist'), findsOneWidget);
  });

  testWidgets('a coming soon row answers with a snackbar and stays open', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('open'));
    await settleSongModal(tester);

    await tapModalAction(tester, 'Edit tags');

    expect(find.text("This isn't available yet. It's coming soon."), findsOne);
    expect(find.text('Go to artist'), findsOneWidget);
  });

  testWidgets('Esc closes the modal', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('open'));
    await settleSongModal(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleSongModal(tester);

    expect(find.text('Go to artist'), findsNothing);
  });
}
