import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/m3u/m3u_write.dart' show M3uPathStyle;
import 'package:kanaru/features/playlists/playlist_actions_menu.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/widgets/queue_actions_menu.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _open(
  WidgetTester tester, {
  ValueChanged<QueueAction>? onQueueAction,
  ValueChanged<M3uPathStyle>? onExport,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PlaylistActionsMenu(
          onQueueAction: onQueueAction,
          onExport: onExport,
        ),
      ),
    ),
  );
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
}

/// Labels and dividers of the open menu, top to bottom ('-' for a divider).
List<String> _layout(WidgetTester tester) {
  final entries = <(double, String)>[
    for (final label in [
      'Export M3U (full paths)…',
      'Export M3U (relative paths)…',
      'Play next',
      'Add to queue',
      'Add to playlist…',
    ])
      for (final e in find.text(label).evaluate())
        (tester.getTopLeft(find.byWidget(e.widget)).dy, label),
    for (final e in find.byType(PopupMenuDivider).evaluate())
      (tester.getTopLeft(find.byElementPredicate((x) => x == e)).dy, '-'),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in entries) e.$2];
}

void main() {
  testWidgets('export rows, a divider, then the queue rows', (tester) async {
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

  testWidgets('nothing playable leaves the export rows only', (tester) async {
    await _open(tester, onExport: (_) {});

    expect(_layout(tester), [
      'Export M3U (full paths)…',
      'Export M3U (relative paths)…',
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
    testWidgets('both exports', (tester) async {
      final styles = <M3uPathStyle>[];
      await _open(tester, onExport: styles.add);
      await tester.tap(find.text('Export M3U (full paths)…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options'));
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
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
      }
      expect(actions, QueueAction.values);
    });
  });
}
