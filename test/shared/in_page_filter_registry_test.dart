import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/in_page_filter_registry.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late InPageFilterRegistry registry;
  final opened = <String>[];

  InPageFilterHandle handle(
    BuildContext context,
    String name, {
    bool focused = false,
    int layer = 0,
    bool available = true,
  }) => InPageFilterHandle(
    context: context,
    open: () => opened.add(name),
    hasFocus: () => focused,
    layer: layer,
    isAvailable: () => available,
  );

  setUp(() {
    registry = InPageFilterRegistry.instance;
    opened.clear();
  });

  Future<BuildContext> pump(WidgetTester tester, [Widget? child]) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return child ?? const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('does nothing without a handle', (tester) async {
    await pump(tester);
    expect(registry.openTop(), isFalse);
    expect(registry.hasFocus, isFalse);
  });

  testWidgets('opens the newest handle only', (tester) async {
    final context = await pump(tester);
    final first = handle(context, 'first');
    final second = handle(context, 'second');
    registry
      ..register(first)
      ..register(second);
    addTearDown(() {
      registry
        ..unregister(first)
        ..unregister(second);
    });

    expect(registry.openTop(), isTrue);
    expect(opened, ['second']);
  });

  testWidgets('an unregistered handle is not opened', (tester) async {
    final context = await pump(tester);
    final only = handle(context, 'only');
    registry
      ..register(only)
      ..unregister(only);

    expect(registry.openTop(), isFalse);
    expect(opened, isEmpty);
  });

  testWidgets('skips a handle whose page is unmounted', (tester) async {
    final context = await pump(tester);
    final gone = handle(context, 'gone');
    registry.register(gone);
    addTearDown(() => registry.unregister(gone));
    await tester.pumpWidget(const SizedBox());

    expect(registry.openTop(), isFalse);
  });

  testWidgets('skips a page under another route', (tester) async {
    final context = await pump(tester);
    final under = handle(context, 'under');
    registry.register(under);
    addTearDown(() => registry.unregister(under));
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    await tester.pumpAndSettle();

    expect(registry.openTop(), isFalse);
  });

  testWidgets('skips a page in a hidden branch', (tester) async {
    late BuildContext inner;
    await pump(
      tester,
      TickerMode(
        enabled: false,
        child: Builder(
          builder: (context) {
            inner = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final hidden = handle(inner, 'hidden');
    registry.register(hidden);
    addTearDown(() => registry.unregister(hidden));

    expect(registry.openTop(), isFalse);
  });

  testWidgets('hasFocus follows the visible handles', (tester) async {
    final context = await pump(tester);
    final focused = handle(context, 'focused', focused: true);
    registry.register(focused);
    addTearDown(() => registry.unregister(focused));

    expect(registry.hasFocus, isTrue);
  });

  testWidgets('a higher layer wins over a newer lower one', (tester) async {
    final context = await pump(tester);
    final overlay = handle(context, 'overlay', layer: 1);
    final page = handle(context, 'page');
    registry
      ..register(overlay)
      ..register(page);
    addTearDown(() {
      registry
        ..unregister(overlay)
        ..unregister(page);
    });

    expect(registry.openTop(), isTrue);
    expect(opened, ['overlay']);
  });

  testWidgets('equal layers: the latest registration wins', (tester) async {
    final context = await pump(tester);
    final a = handle(context, 'a', layer: 1);
    final b = handle(context, 'b', layer: 1);
    registry
      ..register(a)
      ..register(b);
    addTearDown(() {
      registry
        ..unregister(a)
        ..unregister(b);
    });

    registry.openTop();
    expect(opened, ['b']);
  });

  testWidgets('skips a page with nothing to filter', (tester) async {
    final context = await pump(tester);
    final empty = handle(context, 'empty', available: false);
    registry.register(empty);
    addTearDown(() => registry.unregister(empty));

    expect(registry.openTop(), isFalse);
    expect(opened, isEmpty);
  });

  testWidgets('falls back to an available handle below', (tester) async {
    final context = await pump(tester);
    final page = handle(context, 'page');
    final empty = handle(context, 'empty', available: false);
    registry
      ..register(page)
      ..register(empty);
    addTearDown(() {
      registry
        ..unregister(page)
        ..unregister(empty);
    });

    expect(registry.openTop(), isTrue);
    expect(opened, ['page']);
  });
}
