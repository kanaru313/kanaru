import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart' show ColorScheme;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/waveform/waveform.dart';
import 'package:kanaru/features/player/waveform/waveform_bar_layout.dart';
import 'package:kanaru/features/player/waveform/waveform_pictures.dart';
import 'package:kanaru/features/player/waveform/waveform_seek_track.dart';
import 'package:kanaru/features/player/waveform/waveform_track_painter.dart';

const _played = Color(0xFFFF0000);
const _rest = Color(0xFF0000FF);
const _thumb = Color(0xFF00FF00);
const _width = 500.0;

Waveform _loud() => Waveform(
  levels: Uint8List.fromList(List.filled(100, 255)),
  length: const Duration(seconds: 100),
);

WaveformPicturesKey _key(
  Waveform waveform, {
  double width = _width,
  double dpr = 1,
  int durationMs = 100000,
  Color played = _played,
  Color rest = _rest,
}) => (
  waveform: waveform,
  size: Size(width, waveformTrackHeight),
  devicePixelRatio: dpr,
  durationMs: durationMs,
  played: played,
  rest: rest,
);

void main() {
  group('WaveformPictures', () {
    test('the same key gives the same pair without recording again', () {
      final pictures = WaveformPictures();
      addTearDown(pictures.dispose);
      final waveform = _loud();
      final before = WaveformPictures.recordings;

      final first = pictures.pair(_key(waveform));
      final second = pictures.pair(_key(waveform));

      expect(second, same(first));
      expect(WaveformPictures.recordings, before + 1);
    });

    test('a change of width, colour, ratio or duration records anew', () {
      final waveform = _loud();
      final changes = <WaveformPicturesKey>[
        _key(waveform, width: 400),
        _key(waveform, played: const Color(0xFF123456)),
        _key(waveform, rest: const Color(0xFF123456)),
        _key(waveform, dpr: 2),
        _key(waveform, durationMs: 120000),
        _key(_loud()),
      ];
      for (final changed in changes) {
        final pictures = WaveformPictures();
        addTearDown(pictures.dispose);
        final first = pictures.pair(_key(waveform));
        final before = WaveformPictures.recordings;

        final second = pictures.pair(changed);

        expect(WaveformPictures.recordings, before + 1, reason: '$changed');
        expect(second, isNot(same(first)));
        expect(first.played.debugDisposed, isTrue);
        expect(first.rest.debugDisposed, isTrue);
        expect(second.played.debugDisposed, isFalse);
      }
    });

    test('dispose frees the pictures and the next pair records again', () {
      final pictures = WaveformPictures();
      final waveform = _loud();
      final pair = pictures.pair(_key(waveform));

      pictures.dispose();

      expect(pair.played.debugDisposed, isTrue);
      expect(pair.rest.debugDisposed, isTrue);
      final again = pictures.pair(_key(waveform));
      expect(again.played.debugDisposed, isFalse);
      pictures.dispose();
    });
  });

  group('WaveformTrackPainter pixels', () {
    final boundary = GlobalKey();

    Future<ByteData> render(WidgetTester tester, double progress) async {
      final pictures = WaveformPictures();
      addTearDown(pictures.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: _width,
                height: waveformTrackHeight,
                child: CustomPaint(
                  painter: WaveformTrackPainter(
                    progress: progress,
                    thumbColor: _thumb,
                    pictures: pictures.pair(_key(_loud())),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final data = (await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes;
      }))!;
      return data;
    }

    // Colour of the pixel at [x] on row [y] (the track's middle by default).
    Color at(ByteData data, int x, [int? y]) {
      final row = y ?? waveformTrackHeight ~/ 2;
      final offset = (row * _width.toInt() + x) * 4;
      return Color.fromARGB(
        data.getUint8(offset + 3),
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
    }

    // The middle of a bar: bar j starts at 5j and is 3 px wide.
    int barMiddle(int j) => 5 * j + 1;

    testWidgets(
      'played bars left, rest bars right, a clear band at the thumb',
      (tester) async {
        final data = await render(tester, 0.5);

        expect(at(data, barMiddle(25)), _played);
        expect(at(data, barMiddle(75)), _rest);
        expect(at(data, 250), _thumb);
        expect(at(data, 248), _thumb);
        // Beside the thumb nothing is drawn, on both sides, over a full-height
        // bar that would otherwise sit there.
        for (final x in [244, 245, 254, 255]) {
          expect(at(data, x).a, 0, reason: 'x=$x');
        }
      },
    );

    testWidgets('the thumb is shorter than the track', (tester) async {
      final data = await render(tester, 0.5);
      final top = (waveformTrackHeight - waveformThumbHeight) ~/ 2;

      expect(waveformThumbHeight, waveformMaxExtent + 4);
      expect(at(data, 250), _thumb);
      // Two rows in, clear of the pill's rounded end.
      expect(at(data, 250, top + 2), _thumb);
      expect(at(data, 250, top - 2).a, 0);
      expect(at(data, 250, waveformTrackHeight.toInt() - top + 1).a, 0);
    });

    testWidgets('rest bars are drawn after the played ones are clipped', (
      tester,
    ) async {
      final data = await render(tester, 0.1);

      expect(at(data, barMiddle(5)), _played);
      expect(at(data, barMiddle(40)), _rest);
      expect(at(data, barMiddle(99)), _rest);
    });

    testWidgets('the thumb stays inside the track at both ends', (
      tester,
    ) async {
      final start = await render(tester, 0);
      expect(at(start, 1), _thumb);
      expect(at(start, barMiddle(10)), _rest);

      final end = await render(tester, 1);
      expect(at(end, _width.toInt() - 2), _thumb);
      expect(at(end, barMiddle(10)), _played);
    });
  });

  test('played bars are primary at 85 % opacity, the rest at 35 %', () {
    const colors = ColorScheme.light();
    expect(waveformPlayedColor(colors), colors.primary.withValues(alpha: 0.85));
    expect(waveformRestColor(colors), colors.primary.withValues(alpha: 0.35));
  });

  test('shouldRepaint reacts to progress, pictures and thumb colour only', () {
    final pictures = WaveformPictures();
    addTearDown(pictures.dispose);
    final pair = pictures.pair(_key(_loud()));
    WaveformTrackPainter painter(double p, Color c) =>
        WaveformTrackPainter(progress: p, pictures: pair, thumbColor: c);

    expect(painter(0.5, _thumb).shouldRepaint(painter(0.5, _thumb)), isFalse);
    expect(painter(0.6, _thumb).shouldRepaint(painter(0.5, _thumb)), isTrue);
    expect(painter(0.5, _played).shouldRepaint(painter(0.5, _thumb)), isTrue);
    final other = WaveformPictures();
    addTearDown(other.dispose);
    final changed = WaveformTrackPainter(
      progress: 0.5,
      pictures: other.pair(_key(_loud())),
      thumbColor: _thumb,
    );
    expect(changed.shouldRepaint(painter(0.5, _thumb)), isTrue);
  });
}
