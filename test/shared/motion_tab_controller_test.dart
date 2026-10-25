import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/motion_tab_controller.dart';
import 'package:material_ui/material_ui.dart';

/// Builds a controller of [length] tabs the way a page does and reports it.
class _Host extends StatefulWidget {
  const _Host({required this.length, required this.onController});

  final int length;
  final void Function(TabController) onController;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  TabController? _built;

  void _sync() {
    _built = motionTabController(
      context,
      current: _built,
      length: widget.length,
      vsync: this,
      onChanged: () {},
    );
    widget.onController(_built!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _built!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  late TabController controller;

  Future<void> pump(WidgetTester tester, int length) => tester.pumpWidget(
    MaterialApp(
      home: _Host(length: length, onController: (c) => controller = c),
    ),
  );

  testWidgets('keeps its controller while length and motion stay', (
    tester,
  ) async {
    await pump(tester, 2);
    final first = controller;
    await pump(tester, 2);
    expect(controller, same(first));
  });

  testWidgets('a different length gives a new controller on the same tab', (
    tester,
  ) async {
    await pump(tester, 2);
    controller.index = 1;
    final first = controller;

    await pump(tester, 3);

    expect(controller, isNot(same(first)));
    expect(controller.length, 3);
    expect(controller.index, 1);
    await tester.pump();
  });

  testWidgets('a shorter length clamps the index to the last tab', (
    tester,
  ) async {
    await pump(tester, 3);
    controller.index = 2;

    await pump(tester, 1);

    expect(controller.length, 1);
    expect(controller.index, 0);
    await tester.pump();
  });

  testWidgets('reduced motion gives a controller without a slide', (
    tester,
  ) async {
    await pump(tester, 2);
    expect(controller.animationDuration, kTabScrollDuration);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _Host(length: 2, onController: (c) => controller = c),
        ),
      ),
    );

    expect(controller.animationDuration, Duration.zero);
  });
}
