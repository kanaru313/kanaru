import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../core/waveform/waveform.dart';
import 'waveform_bar_layout.dart';
import 'waveform_level_contrast.dart';

/// What the bars depend on: change any of it and they are drawn again.
/// [waveform] is compared by identity, so a new load re-records.
typedef WaveformPicturesKey = ({
  Waveform waveform,
  ui.Size size,
  double devicePixelRatio,
  int durationMs,
  ui.Color played,
  ui.Color rest,
});

/// The bars drawn once in the played colour and once in the rest colour.
typedef WaveformPicturePair = ({ui.Picture played, ui.Picture rest});

/// Keeps the recorded bars of one waveform track. A position tick must not
/// record again: [pair] returns the same pictures until its key changes.
/// Replaced pictures are disposed, so are the last ones on [dispose].
class WaveformPictures {
  WaveformPicturesKey? _key;
  WaveformPicturePair? _pair;

  /// How many times bars were recorded, for tests.
  @visibleForTesting
  static int recordings = 0;

  /// The pictures for [key]: the kept pair, or a newly recorded one.
  WaveformPicturePair pair(WaveformPicturesKey key) {
    final kept = _pair;
    if (kept != null && key == _key) return kept;
    dispose();
    recordings++;
    final recorded = _record(key);
    _key = key;
    return _pair = recorded;
  }

  /// Releases the pictures. The next [pair] records again.
  void dispose() {
    _pair?.played.dispose();
    _pair?.rest.dispose();
    _pair = null;
    _key = null;
  }

  static WaveformPicturePair _record(WaveformPicturesKey key) {
    final extents = waveformBarExtents(
      levels: waveformContrastLevels(key.waveform.levels),
      length: key.waveform.length,
      duration: Duration(milliseconds: key.durationMs),
      width: key.size.width,
    );
    ui.Picture draw(ui.Color color) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = color;
      final dpr = key.devicePixelRatio;
      final centre = key.size.height / 2;
      for (var j = 0; j < extents.length; j++) {
        // Both edges snapped to a device pixel so the bars stay crisp.
        double snap(double v) => (v * dpr).roundToDouble() / dpr;
        final start = j * (waveformBarWidth + waveformBarGap);
        final x = snap(start);
        final right = snap(start + waveformBarWidth);
        canvas.drawRRect(
          ui.RRect.fromLTRBR(
            x,
            centre - extents[j] / 2,
            right,
            centre + extents[j] / 2,
            const ui.Radius.circular(waveformBarRadius),
          ),
          paint,
        );
      }
      return recorder.endRecording();
    }

    return (played: draw(key.played), rest: draw(key.rest));
  }
}
