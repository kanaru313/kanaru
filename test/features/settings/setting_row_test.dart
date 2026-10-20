import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/setting_row.dart';
import 'package:material_ui/material_ui.dart';

/// Row widths on both sides of the width below which rows are narrow.
const _narrow = 400.0;
const _wide = 800.0;

void main() {
  testWidgets('a single control is built once and survives the row turning '
      'narrow and back', (tester) async {
    var mounts = 0;
    final control = _MountCounter(
      onMount: () => mounts++,
      child: const SizedBox(width: 120, height: 40),
    );
    Future<void> pump(double width) => _pumpRow(
      tester,
      width,
      SettingRow.single(title: 'Title', control: control),
    );

    await pump(_wide);
    expect(find.byType(_MountCounter, skipOffstage: false), findsOneWidget);
    expect(tester.getSize(find.byType(_MountCounter)).width, 120);

    await pump(_narrow);
    expect(find.byType(_MountCounter, skipOffstage: false), findsOneWidget);
    expect(
      tester.getSize(find.byType(_MountCounter)).width,
      200,
      reason: 'the compact width',
    );

    await pump(_wide);
    expect(mounts, 1);
  });

  testWidgets('a compact control already shown survives the row turning '
      'narrow and back', (tester) async {
    final mounts = <bool, int>{};
    Future<void> pump(double width) => _pumpRow(
      tester,
      width,
      SettingRow(
        title: 'Title',
        control: (compact) => _MountCounter(
          onMount: () => mounts[compact] = (mounts[compact] ?? 0) + 1,
          // Too wide for even a wide row.
          child: SizedBox(width: compact ? 100 : 700, height: 40),
        ),
      ),
    );

    await pump(_wide);
    expect(tester.getSize(find.byType(_MountCounter)).width, 200);
    await pump(_narrow);
    await pump(_wide);
    expect(mounts[true], 1);
  });
}

Future<void> _pumpRow(WidgetTester tester, double width, Widget row) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: row),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Calls [onMount] each time it is mounted.
class _MountCounter extends StatefulWidget {
  const _MountCounter({required this.onMount, required this.child});

  final VoidCallback onMount;
  final Widget child;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
