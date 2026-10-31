import 'package:flutter/gestures.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/l10n/app_localizations.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_marquee_label.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_source_menu.dart';
import 'package:material_ui/material_ui.dart';

class _Host extends StatefulWidget {
  const _Host({required this.sources, required this.names, this.initial});

  final List<({String id, int count})> sources;
  final Map<String, String> names;
  final String? initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? selected = widget.initial;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: LyricsPickerSourceMenu(
        sources: widget.sources,
        providerNames: widget.names,
        selected: selected,
        onSelected: (id) => setState(() => selected = id),
      ),
    ),
  );
}

void main() {
  final longName = List.filled(80, 'W').join();
  const two = [(id: 'a', count: 11), (id: 'b', count: 6)];

  Future<void> pump(
    WidgetTester tester, {
    List<({String id, int count})> sources = two,
    Map<String, String>? names,
    String? initial,
    bool disableAnimations = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1000, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: Scaffold(
          body: _Host(
            sources: sources,
            names: names ?? {'a': 'Alpha', 'b': 'Beta'},
            initial: initial,
          ),
        ),
      ),
    );
  }

  Finder chip() => find.byType(OutlinedButton);
  Finder item(String name) => find.widgetWithText(MenuItemButton, name);

  /// Whether the marquee text has moved from its start.
  double scrolled(WidgetTester tester) {
    final transform = find.descendant(
      of: find.byType(LyricsPickerMarqueeLabel),
      matching: find.byType(Transform),
    );
    if (transform.evaluate().isEmpty) return 0;
    return tester
        .widget<Transform>(transform.first)
        .transform
        .getTranslation()
        .x;
  }

  testWidgets('unfiltered chip: label, fixed width, no check', (tester) async {
    await pump(tester);
    expect(find.text('All sources (2)'), findsOneWidget);
    expect(tester.getSize(chip()).width, 200);
    expect(
      find.descendant(of: chip(), matching: find.byIcon(Icons.check)),
      findsNothing,
    );
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });

  testWidgets('menu lists the total and the counts, check on current only', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(chip());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: item('All sources'), matching: find.text('17')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: item('Alpha'), matching: find.text('11')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: item('Beta'), matching: find.text('6')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.descendant(
        of: item('All sources'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking a source shows its name on a tinted chip', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(chip());
    await tester.pumpAndSettle();
    await tester.tap(item('Beta'));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('All sources (2)'), findsNothing);
    final scheme = Theme.of(tester.element(chip())).colorScheme;
    final button = tester.widget<OutlinedButton>(chip());
    final bg = button.style!.backgroundColor!.resolve(<WidgetState>{});
    expect(bg, scheme.secondaryContainer);
    expect(tester.getSize(chip()).width, 200);

    await tester.tap(chip());
    await tester.pumpAndSettle();
    await tester.tap(item('All sources'));
    await tester.pumpAndSettle();
    expect(find.text('All sources (2)'), findsOneWidget);
  });

  testWidgets('fewer than two sources: disabled chip, plain label', (
    tester,
  ) async {
    for (final sources in [
      const <({String id, int count})>[],
      const [(id: 'a', count: 3)],
    ]) {
      await pump(tester, sources: sources);
      expect(find.text('All sources'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(chip()).onPressed, isNull);
      expect(tester.getSize(chip()).width, 200);
      await tester.tap(chip(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
    }
  });

  testWidgets('semantics name the button once', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(
      find.bySemanticsLabel('Source filter: All sources (2)'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('80-character name: clipped chip, wrapped item, tooltip', (
    tester,
  ) async {
    await pump(tester, names: {'a': longName, 'b': 'Beta'}, initial: 'a');
    expect(tester.takeException(), isNull);
    expect(tester.getSize(chip()).width, 200);
    expect(find.byTooltip(longName), findsOneWidget);

    await tester.tap(chip());
    await tester.pumpAndSettle();
    // The tooltip never sits over the open menu.
    expect(find.byTooltip(longName), findsNothing);
    final name = find.descendant(
      of: item(longName),
      matching: find.text(longName),
    );
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(name);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.getSize(item(longName)).height, greaterThan(44));
    expect(tester.getSize(item(longName)).width, lessThanOrEqualTo(320));
  });

  group('marquee', () {
    Future<TestGesture> hover(WidgetTester tester) async {
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      addTearDown(g.removePointer);
      await tester.pump();
      await g.moveTo(tester.getCenter(chip()));
      await tester.pump();
      return g;
    }

    testWidgets('moves while hovered, rests when the pointer leaves', (
      tester,
    ) async {
      await pump(tester, names: {'a': longName, 'b': 'Beta'}, initial: 'a');
      final g = await hover(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(scrolled(tester), lessThan(0));

      await g.moveTo(const Offset(900, 600));
      await tester.pump();
      await tester.pump();
      expect(scrolled(tester), 0);
    });

    testWidgets('does not move with animations disabled', (tester) async {
      await pump(
        tester,
        names: {'a': longName, 'b': 'Beta'},
        initial: 'a',
        disableAnimations: true,
      );
      await hover(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(scrolled(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('moves when focused with the keyboard', (tester) async {
      await pump(tester, names: {'a': longName, 'b': 'Beta'}, initial: 'a');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(scrolled(tester), lessThan(0));
    });

    testWidgets('focus back after a mouse click does not move it', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester, names: {'a': longName, 'b': 'Beta'}, initial: 'a');
        // Focus the chip with the keyboard first, then use only the mouse.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final g = await hover(tester);
        await g.down(tester.getCenter(chip()));
        await g.up();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(MenuItemButton), findsWidgets);
        await g.moveTo(tester.getCenter(item(longName)));
        await tester.pump();
        await g.down(tester.getCenter(item(longName)));
        await g.up();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(MenuItemButton), findsNothing);
        await g.moveTo(const Offset(900, 600));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 3));
        expect(scrolled(tester), 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('the current item is selected for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, initial: 'b');
    await tester.tap(chip());
    await tester.pumpAndSettle();
    SemanticsNode node(String name) => tester.getSemantics(
      find.descendant(of: item(name), matching: find.text(name)),
    );
    expect(
      node('Beta').getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      node('Alpha').getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );
    handle.dispose();
  });
}
