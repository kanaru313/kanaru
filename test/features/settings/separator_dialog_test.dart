import 'dart:ui' show PointerDeviceKind, SemanticsAction, Tristate;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/settings/settings_provider.dart';
import 'package:kanaru/features/settings/separator_dialog.dart';
import 'package:kanaru/features/settings/separator_list_pages.dart';
import 'package:kanaru/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

late ProviderContainer _container;

SplitPrefs _artist() =>
    _container.read(settingsProvider).libraryScan.artistSplit;
SplitPrefs _genre() => _container.read(settingsProvider).libraryScan.genreSplit;

/// Opens the dialog for [kind] over an app that starts from [settings].
Future<void> _open(
  WidgetTester tester, {
  SeparatorKind kind = SeparatorKind.artist,
  AppSettings settings = const AppSettings(),
  String language = 'en',
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _container = ProviderContainer(
    overrides: [initialSettingsProvider.overrideWithValue(settings)],
  );
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSeparatorDialog(context, kind),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _tapAdd(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add'));
  await tester.pumpAndSettle();
}

Future<void> _openKeepTab(WidgetTester tester, int count) async {
  await tester.tap(find.text('Keep whole ($count)'));
  await tester.pumpAndSettle();
}

AppSettings _withArtist(SplitPrefs split) =>
    AppSettings(libraryScan: LibraryScanPrefs(artistSplit: split));

void main() {
  testWidgets('shows two tabs with the number of entries', (tester) async {
    await _open(tester);

    expect(find.text('Split artists'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Separators (9)'), findsOneWidget);
    expect(find.text('Keep whole (1)'), findsOneWidget);
    // The defaults are listed, symbols included.
    for (final entry in defaultArtistSeparators) {
      expect(find.text(entry), findsOneWidget, reason: entry);
    }
    expect(
      find.text(
        'No need to add spaces around it. '
        'Words like feat. split only with a space on each side.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Add saves the trimmed entry at once and updates the count', (
    tester,
  ) async {
    await _open(tester);
    await _type(tester, '  &  ');
    await _tapAdd(tester);

    expect(_artist().separators.last, '&');
    expect(_artist().keepWhole, defaultArtistKeepWhole);
    expect(find.text('Separators (9)'), findsOneWidget);
    expect(find.text('&'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('Enter adds too, and the field keeps the focus', (tester) async {
    await _open(tester);
    await _type(tester, 'vs.');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_artist().separators.last, 'vs.');
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
  });

  testWidgets('an empty entry is refused and the message clears on typing', (
    tester,
  ) async {
    await _open(tester);
    await _type(tester, '   ');
    await _tapAdd(tester);

    expect(find.text('Type something to add'), findsOneWidget);
    expect(_artist(), defaultArtistSplit);

    await _type(tester, 'x');
    await tester.pumpAndSettle();
    expect(find.text('Type something to add'), findsNothing);
  });

  testWidgets('a repeat is refused in any case', (tester) async {
    await _open(tester);
    await _type(tester, ' FEAT. ');
    await _tapAdd(tester);

    expect(find.text('Already in the list'), findsOneWidget);
    expect(_artist(), defaultArtistSplit);
  });

  testWidgets('an entry over the limit is refused, the limit itself is not', (
    tester,
  ) async {
    await _open(tester);
    await _type(tester, 'a' * (maxSplitEntryLength + 1));
    await _tapAdd(tester);
    expect(
      find.text('At most $maxSplitEntryLength characters'),
      findsOneWidget,
    );
    expect(_artist(), defaultArtistSplit);

    await _type(tester, 'a' * maxSplitEntryLength);
    await _tapAdd(tester);
    expect(_artist().separators.last, 'a' * maxSplitEntryLength);
  });

  testWidgets('a full list refuses another entry', (tester) async {
    final full = [for (var i = 0; i < maxSplitEntries; i++) 's$i'];
    await _open(
      tester,
      settings: _withArtist(SplitPrefs(separators: full, keepWhole: const [])),
    );
    await _type(tester, 'extra');
    await _tapAdd(tester);

    expect(
      find.text('The list holds at most $maxSplitEntries entries'),
      findsOneWidget,
    );
    expect(_artist().separators, full);
  });

  testWidgets('the remove button of an entry deletes just that entry', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Remove with'));
    await tester.pumpAndSettle();

    expect(_artist().separators, [
      for (final s in defaultArtistSeparators)
        if (s != 'with') s,
    ]);
    expect(find.text('Separators (7)'), findsOneWidget);
    expect(find.text('with'), findsNothing);
  });

  testWidgets('the keep-whole tab adds and removes on its own list', (
    tester,
  ) async {
    await _open(tester);
    await _openKeepTab(tester, 1);
    expect(find.text('AC/DC'), findsOneWidget);
    expect(find.textContaining('AC/DC, for example'), findsOneWidget);

    await _type(tester, 'Simon / Garfunkel');
    await _tapAdd(tester);
    expect(_artist().keepWhole, ['AC/DC', 'Simon / Garfunkel']);
    expect(_artist().separators, defaultArtistSeparators);
    expect(find.text('Keep whole (2)'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove AC/DC'));
    await tester.pumpAndSettle();
    expect(_artist().keepWhole, ['Simon / Garfunkel']);
  });

  testWidgets('empty lists say so', (tester) async {
    await _open(
      tester,
      settings: _withArtist(const SplitPrefs(separators: [], keepWhole: [])),
    );
    expect(find.text('Nothing here yet, so nothing is split'), findsOneWidget);
    await _openKeepTab(tester, 0);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('a half-typed entry survives a tab switch', (tester) async {
    await _open(tester);
    await _type(tester, 'half');
    await _openKeepTab(tester, 1);
    await tester.tap(find.text('Separators (9)'));
    await tester.pumpAndSettle();

    expect(find.text('half'), findsOneWidget);
  });

  testWidgets('with reduced motion tabs and pages change in one frame', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(tester);
    await _type(tester, '&');
    await _tapAdd(tester);
    expect(find.text('&').hitTestable(), findsOneWidget);

    // Ink ripples are the framework's and still run; the page and the tab
    // indicator must not.
    await tester.tap(find.byTooltip('Page 1 of 2'));
    await tester.pump();
    final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(pages.page, 0);
    expect(find.text(';').hitTestable(), findsOneWidget);

    await tester.tap(find.textContaining('Keep whole'));
    await tester.pump();
    final tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    expect(tabs.index, 1);
    expect(tabs.animation!.value, 1);
  });

  group('paging', () {
    testWidgets('eight entries fit one page without dots', (tester) async {
      await _open(tester);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byTooltip('Page 1 of 2'), findsNothing);
    });

    testWidgets('a ninth entry opens a second page with dots', (tester) async {
      await _open(tester);
      expect(defaultArtistSeparators, hasLength(separatorPageSize));
      await _type(tester, '&');
      await _tapAdd(tester);

      // The new entry is last: the dialog turns to its page.
      expect(find.byTooltip('Page 1 of 2'), findsOneWidget);
      expect(find.byTooltip('Page 2 of 2'), findsOneWidget);
      expect(find.text('&').hitTestable(), findsOneWidget);
      expect(find.text(';'), findsNothing, reason: 'first page is off screen');

      await tester.tap(find.byTooltip('Page 1 of 2'));
      await tester.pumpAndSettle();
      expect(find.text(';').hitTestable(), findsOneWidget);
      expect(find.text('&'), findsNothing);

      await tester.tap(find.byTooltip('Page 2 of 2'));
      await tester.pumpAndSettle();
      expect(find.text('&').hitTestable(), findsOneWidget);
    });

    testWidgets('a dot is a button for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester);
      await _type(tester, '&');
      await _tapAdd(tester);

      final first = tester.getSemantics(find.bySemanticsLabel('Page 1 of 2'));
      final data = first.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isFalse);
      final second = tester.getSemantics(find.bySemanticsLabel('Page 2 of 2'));
      expect(
        second.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      tester.semantics.tap(find.semantics.byLabel('Page 1 of 2'));
      await tester.pumpAndSettle();
      expect(find.text(';').hitTestable(), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Tab reaches a dot and Enter or Space opens its page', (
      tester,
    ) async {
      await _open(tester);
      await _type(tester, '&');
      await _tapAdd(tester);
      expect(find.text(';'), findsNothing, reason: 'on the second page');

      Future<void> tabTo(String tooltip) async {
        for (var i = 0; i < 40; i++) {
          final focus = FocusManager.instance.primaryFocus?.context;
          if (focus?.findAncestorWidgetOfExactType<Tooltip>()?.message ==
              tooltip) {
            return;
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        fail('Tab never reached $tooltip');
      }

      await tabTo('Page 1 of 2');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(';').hitTestable(), findsOneWidget);
      expect(find.text('&'), findsNothing);

      await tabTo('Page 2 of 2');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('&').hitTestable(), findsOneWidget);
    });

    testWidgets('a large text size does not cut the entries', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester);

      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(';'));
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
        maxLines: 1,
      )..layout();
      expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
      // Eight rows still make one page at this size.
      expect(find.text('with').hitTestable(), findsOneWidget);
    });

    testWidgets('removing the only entry of the last page steps back', (
      tester,
    ) async {
      await _open(tester);
      await _type(tester, '&');
      await _tapAdd(tester);
      await tester.tap(find.byTooltip('Remove &'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Page 1 of 2'), findsNothing);
      expect(find.text(';').hitTestable(), findsOneWidget);
    });

    testWidgets('a page swipe turns the page', (tester) async {
      await _open(tester);
      await _type(tester, '&');
      await _tapAdd(tester);
      await tester.tap(find.byTooltip('Page 1 of 2'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(PageView),
        const Offset(-400, 0),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();
      expect(find.text('&').hitTestable(), findsOneWidget);
    });
  });

  group('restore defaults', () {
    testWidgets('is off while the rules are the defaults', (tester) async {
      await _open(tester);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Restore defaults'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('asks first, then puts both lists back', (tester) async {
      await _open(
        tester,
        settings: _withArtist(
          const SplitPrefs(separators: ['&'], keepWhole: ['x']),
        ),
      );
      await tester.tap(find.text('Restore defaults'));
      await tester.pumpAndSettle();
      expect(find.text('Restore defaults?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_artist().separators, ['&']);

      await tester.tap(find.text('Restore defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();
      expect(_artist(), defaultArtistSplit);
      expect(find.text('Separators (9)'), findsOneWidget);
    });
  });

  testWidgets('the genre dialog edits only the genre rules', (tester) async {
    await _open(tester, kind: SeparatorKind.genre);

    expect(find.text('Split genres'), findsOneWidget);
    expect(find.text('Separators (1)'), findsOneWidget);
    expect(find.text('Keep whole (0)'), findsOneWidget);
    await _type(tester, '/');
    await _tapAdd(tester);

    expect(_genre().separators, [';', '/']);
    expect(_artist(), defaultArtistSplit);

    await _openKeepTab(tester, 0);
    expect(find.textContaining('Funk/Soul, for example'), findsOneWidget);
  });

  testWidgets('a change keeps the other scan options', (tester) async {
    await _open(
      tester,
      settings: const AppSettings(
        libraryScan: LibraryScanPrefs(respectNomedia: true, minFileSizeKb: 500),
      ),
    );
    await _type(tester, '&');
    await _tapAdd(tester);

    final scan = _container.read(settingsProvider).libraryScan;
    expect(scan.respectNomedia, isTrue);
    expect(scan.minFileSizeKb, 500);
    expect(scan.artistSplit.separators.last, '&');
  });

  testWidgets('speaks Vietnamese', (tester) async {
    await _open(tester, language: 'vi');

    expect(find.text('Tách nghệ sĩ'), findsOneWidget);
    expect(find.text('Dấu phân cách (9)'), findsOneWidget);
    expect(find.text('Không tách (1)'), findsOneWidget);
    expect(find.textContaining('Không cần thêm khoảng trắng'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập nội dung cần thêm'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'FEAT');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Đã có trong danh sách'), findsOneWidget);
    expect(find.byTooltip('Xoá with'), findsOneWidget);
  });
}
