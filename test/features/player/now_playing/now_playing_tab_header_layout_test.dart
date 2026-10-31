import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/player/now_playing/now_playing_tab_header_layout.dart';
import 'package:material_ui/material_ui.dart';

const _leftKey = Key('left');
const _dotsKey = Key('dots');
const _leftWidth = 176.0;
const _dotsWidth = 88.0;
const _start = nowPlayingTabHeaderStartPadding;
const _gap = nowPlayingTabHeaderMinGap;

void main() {
  /// Pumps the layout in a header [width] wide, centered on [centerX].
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required double centerX,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 64,
            child: CustomMultiChildLayout(
              delegate: NowPlayingTabHeaderLayout(windowCenterX: centerX),
              children: [
                LayoutId(
                  id: NowPlayingTabHeaderSlot.left,
                  child: const SizedBox(
                    key: _leftKey,
                    width: _leftWidth,
                    height: 40,
                  ),
                ),
                LayoutId(
                  id: NowPlayingTabHeaderSlot.dots,
                  child: const SizedBox(
                    key: _dotsKey,
                    width: _dotsWidth,
                    height: 26,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Rect left(WidgetTester tester) => tester.getRect(find.byKey(_leftKey));
  Rect dots(WidgetTester tester) => tester.getRect(find.byKey(_dotsKey));

  testWidgets('centers the dots on the window when there is room', (
    tester,
  ) async {
    await pump(tester, width: 800, centerX: 400);

    expect(dots(tester).center.dx, 400);
    expect(left(tester).left, _start);
    expect(left(tester).center.dy, 32);
    expect(dots(tester).center.dy, 32);
  });

  testWidgets('keeps the minimum strip after the buttons when tight', (
    tester,
  ) async {
    await pump(tester, width: 400, centerX: 240);

    // Measured on Linux at 480: buttons end at 184, centered dots started at
    // 196 (12 px strip).
    expect(dots(tester).left, _start + _leftWidth + _gap);
    expect(dots(tester).left - left(tester).right, _gap);
  });

  testWidgets('keeps the strip even when the dots then reach the end', (
    tester,
  ) async {
    await pump(tester, width: 280, centerX: 140);

    expect(dots(tester).left, _start + _leftWidth + _gap);
    // The strip after the buttons wins over the end margin.
    expect(dots(tester).right, greaterThan(280 - _gap));
  });

  testWidgets('keeps a strip before the header end when the window is offset', (
    tester,
  ) async {
    // Wide header whose window center lies past its end (window buttons).
    await pump(tester, width: 500, centerX: 520);

    expect(dots(tester).right, 500 - _gap);
  });

  testWidgets('relayouts only when the window center moves', (tester) async {
    final a = NowPlayingTabHeaderLayout(windowCenterX: 240);

    expect(
      a.shouldRelayout(NowPlayingTabHeaderLayout(windowCenterX: 240)),
      false,
    );
    expect(
      a.shouldRelayout(NowPlayingTabHeaderLayout(windowCenterX: 300)),
      true,
    );
  });
}
