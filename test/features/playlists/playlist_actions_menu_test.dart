import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_write.dart' show M3uPathStyle;
import 'package:kanaru/features/playlists/playlist_actions_menu.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _open(
  WidgetTester tester, {
  ValueChanged<QueueAction>? onQueueAction,
  VoidCallback? onRename,
  VoidCallback? onDelete,
  ValueChanged<M3uPathStyle>? onExport,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PlaylistActionsMenu(
          onQueueAction: onQueueAction,
          onRename: onRename,
          onDelete: onDelete,
          onExport: onExport,
        ),
      ),
    ),
  );
  await tester.tap(find.byTooltip('Playlist actions'));
  await tester.pumpAndSettle();
}

/// Labels and dividers of the open menu, top to bottom ('-' for a divider).
List<String> _layout(WidgetTester tester) {
  final entries = <(double, String)>[
    for (final label in [
      'Rename',
      'Export M3U (full paths)…',
      'Export M3U (relative paths)…',
      'Play next',
      'Add to queue',
      'Add to playlist…',
      'Delete playlist',
    ])
      for (final e in find.text(label).evaluate())
        (tester.getTopLeft(find.byWidget(e.widget)).dy, label),
    for (final e in find.byType(PopupMenuDivider).evaluate())
      (tester.getTopLeft(find.byElementPredicate((x) => x == e)).dy, '-'),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in entries) e.$2];
}

void main() {
  void noop() {}

  testWidgets('a normal playlist: edit, queue, delete, split by dividers', (
    tester,
  ) async {
    await _open(
      tester,
      onQueueAction: (_) {},
      onRename: noop,
      onDelete: noop,
      onExport: (_) {},
    );

    expect(_layout(tester), [
      'Rename',
      'Export M3U (full paths)…',
      'Export M3U (relative paths)…',
      '-',
      'Play next',
      'Add to queue',
      'Add to playlist…',
      '-',
      'Delete playlist',
    ]);
  });

  testWidgets('Favorites has no Rename or Delete and no stray divider', (
    tester,
  ) async {
    await _open(tester, onQueueAction: (_) {}, onExport: (_) {});

    expect(_layout(tester), [
      'Export M3U (full paths)…',
      'Export M3U (relative paths)…',
      '-',
      'Play next',
      'Add to queue',
      'Add to playlist…',
    ]);
  });

  testWidgets('nothing playable leaves the edit rows and Delete', (
    tester,
  ) async {
    await _open(tester, onRename: noop, onDelete: noop, onExport: (_) {});

    expect(_layout(tester), [
      'Rename',
      'Export M3U (full paths)…',
      'Export M3U (relative paths)…',
      '-',
      'Delete playlist',
    ]);
  });

  testWidgets('only the queue rows: no divider at all', (tester) async {
    await _open(tester, onQueueAction: (_) {});

    expect(find.byType(PopupMenuDivider), findsNothing);
    expect(find.text('Play next'), findsOneWidget);
  });

  testWidgets('no callbacks, no rows to open', (tester) async {
    const menu = PlaylistActionsMenu();
    expect(menu.hasItems, isFalse);
  });

  group('each row calls its callback', () {
    testWidgets('Rename', (tester) async {
      var n = 0;
      await _open(tester, onRename: () => n++);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(n, 1);
    });

    testWidgets('Delete', (tester) async {
      var n = 0;
      await _open(tester, onDelete: () => n++);
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();
      expect(n, 1);
    });

    testWidgets('both exports', (tester) async {
      final styles = <M3uPathStyle>[];
      await _open(tester, onExport: styles.add);
      await tester.tap(find.text('Export M3U (full paths)…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Playlist actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export M3U (relative paths)…'));
      await tester.pumpAndSettle();
      expect(styles, [M3uPathStyle.absolute, M3uPathStyle.relative]);
    });

    testWidgets('the queue rows', (tester) async {
      final actions = <QueueAction>[];
      await _open(tester, onQueueAction: actions.add);
      for (final label in ['Play next', 'Add to queue', 'Add to playlist…']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Playlist actions'));
        await tester.pumpAndSettle();
      }
      expect(actions, QueueAction.values);
    });
  });
}
