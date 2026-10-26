import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:kanaru/core/player/track.dart';
import 'package:kanaru/features/player/queue/queue_panel_header.dart';
import 'package:kanaru/features/player/queue/queue_time_left.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/player/fake_audio_backend.dart';

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  /// Pumps the header with the real summary text inside a [width] box.
  Future<void> pumpHeader(
    WidgetTester tester, {
    required double width,
    Locale locale = const Locale('en'),
    double textScale = 1,
    int tracks = 876,
    Duration? duration = const Duration(minutes: 3),
    VoidCallback? onSave,
    VoidCallback? onClear,
    VoidCallback? onClose,
  }) async {
    backend = FakeAudioBackend();
    container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    addTearDown(container.dispose);
    await container.read(playerServiceProvider.notifier).openTracks([
      for (var i = 0; i < tracks; i++)
        Track(uri: '/m/$i.mp3', title: 't$i', duration: duration),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: Builder(
                    builder: (context) {
                      return QueuePanelHeader(
                        summary: const QueueSummaryText(),
                        filterOpen: false,
                        onFilter: () {},
                        onSave: onSave,
                        onClear: onClear,
                        onShowCurrent: () {},
                        onClose: onClose,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('title and summary are not cut off at 432 px', (tester) async {
    await pumpHeader(tester, width: 432, onClose: () {});

    expect(find.text('Now playing'), findsOneWidget);
    // 876 x 3 min = 43 h 48 min.
    final summary = find.text('876 tracks · 43 h 48 min left');
    expect(summary, findsOneWidget);
    // The test font is as wide as it is tall, far wider than a real font,
    // so the summary is only checked for the one line it must stay on; the
    // title row has the width of the whole box.
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Now playing'))
          .didExceedMaxLines,
      isFalse,
    );
    expect(tester.widget<Text>(summary).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both rows fit at 360 px and 150 % text in Vietnamese', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      width: 360,
      locale: const Locale('vi'),
      textScale: 1.5,
      onClose: () {},
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Đang phát'), findsOneWidget);
    expect(find.byTooltip('Thêm thao tác'), findsOneWidget);
  });

  testWidgets('a long time left fits at 440 px, vi, text scale 1.25', (
    tester,
  ) async {
    // 876 tracks of 3 min: 43 h 48 min left.
    await pumpHeader(
      tester,
      width: 440,
      locale: const Locale('vi'),
      textScale: 1.25,
      onClose: () {},
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('43 giờ 48 phút'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? "").contains("43 giờ 48 phút"),
      ),
      findsOneWidget,
    );
  });

  testWidgets('menu items follow the callbacks', (tester) async {
    await pumpHeader(tester, width: 432);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();

    MenuItemButton item(String label) =>
        tester.widget(find.widgetWithText(MenuItemButton, label));
    expect(item('Save queue as playlist').onPressed, isNull);
    expect(item('Clear queue').onPressed, isNull);
  });

  testWidgets('menu items run their callbacks', (tester) async {
    var saved = 0;
    var cleared = 0;
    await pumpHeader(
      tester,
      width: 432,
      onSave: () => saved++,
      onClear: () => cleared++,
    );

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save queue as playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear queue'));
    await tester.pumpAndSettle();

    expect([saved, cleared], [1, 1]);
  });

  testWidgets('the overflow button has an accessible name', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHeader(tester, width: 432);

    final node = tester.getSemantics(find.byTooltip('More actions'));
    expect(node.label, 'More actions');
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('only the track count shows when durations are unknown', (
    tester,
  ) async {
    await pumpHeader(tester, width: 432, tracks: 5, duration: null);

    expect(find.text('5 tracks'), findsOneWidget);
  });

  testWidgets('the summary rebuilds only when the minute shown changes', (
    tester,
  ) async {
    await pumpHeader(tester, width: 432, tracks: 3);
    final summary = find.text('3 tracks · 9 min left');
    final shown = tester.widget<Text>(summary);

    // A rebuilt summary would be a new Text widget.
    for (var s = 1; s <= 30; s++) {
      backend.emitPosition.add(Duration(seconds: s));
      await tester.pump();
    }
    expect(tester.widget<Text>(summary), same(shown));

    backend.emitPosition.add(const Duration(minutes: 1, seconds: 5));
    await tester.pump();
    expect(find.text('3 tracks · 8 min left'), findsOneWidget);
  });

  testWidgets('no time part once less than a minute is left', (tester) async {
    await pumpHeader(tester, width: 432, tracks: 1);
    backend.emitPosition.add(
      const Duration(minutes: 2, seconds: 59, milliseconds: 500),
    );
    await tester.pump();
    expect(find.text('1 track · 1 min left'), findsOneWidget);

    backend.emitPosition.add(const Duration(minutes: 3));
    await tester.pump();
    expect(find.text('1 track'), findsOneWidget);
  });

  testWidgets('header buttons are named once and the menu reports state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHeader(tester, width: 432, onClose: () {});

    for (final label in [
      'Close now playing list',
      'Jump to current song',
      'More actions',
    ]) {
      final node = tester.getSemantics(find.byTooltip(label));
      expect(node.label, label);
    }
    expect(
      tester
          .getSemantics(find.byTooltip('More actions'))
          .flagsCollection
          .isExpanded,
      Tristate.isFalse,
    );
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byTooltip('More actions'))
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );
    handle.dispose();
  });
}
