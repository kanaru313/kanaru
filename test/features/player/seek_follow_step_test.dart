import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/player/seek_follow_step.dart';

const _ms250 = Duration(milliseconds: 250);
const _ms500 = Duration(milliseconds: 500);
const _second = Duration(seconds: 1);

void main() {
  group('seekFollowStep', () {
    // 100 px wide: a track of 100 x n ms stands for n ms per pixel.
    Duration step(double millisPerPixel, {double width = 100}) =>
        seekFollowStep(
          Duration(microseconds: (millisPerPixel * width * 1000).round()),
          width,
        );

    test('takes the smallest step at least as long as a pixel', () {
      expect(step(1), _ms250);
      expect(step(250), _ms250);
      expect(step(250.001), _ms500);
      expect(step(500), _ms500);
      expect(step(500.001), _second);
      expect(step(1000), _second);
    });

    test('caps at one second on long tracks', () {
      expect(step(5000), _second);
    });

    test('does not depend on the track having this exact width', () {
      expect(step(250, width: 565), _ms250);
      expect(step(250.001, width: 565), _ms500);
    });

    test('falls back to one second when the width is unusable', () {
      const duration = Duration(minutes: 3);
      expect(seekFollowStep(duration, 0), _second);
      expect(seekFollowStep(duration, -10), _second);
      expect(seekFollowStep(duration, double.infinity), _second);
      expect(seekFollowStep(duration, double.nan), _second);
    });

    test('falls back to one second when nothing is loaded', () {
      expect(seekFollowStep(Duration.zero, 500), _second);
      expect(seekFollowStep(const Duration(seconds: -1), 500), _second);
    });

    test('every step divides a second', () {
      for (final step in seekFollowSteps) {
        expect(_second.inMilliseconds % step.inMilliseconds, 0);
      }
    });
  });

  group('seekShownPosition', () {
    test('floors to the step', () {
      expect(
        seekShownPosition(const Duration(milliseconds: 1249), _ms250),
        const Duration(seconds: 1),
      );
      expect(
        seekShownPosition(const Duration(milliseconds: 1250), _ms250),
        const Duration(milliseconds: 1250),
      );
      expect(
        seekShownPosition(const Duration(milliseconds: 1999), _second),
        const Duration(seconds: 1),
      );
      expect(
        seekShownPosition(const Duration(milliseconds: 1999), _ms500),
        const Duration(milliseconds: 1500),
      );
    });

    test('shows zero for a negative position', () {
      expect(
        seekShownPosition(const Duration(seconds: -3), _ms250),
        Duration.zero,
      );
      expect(seekShownPosition(Duration.zero, _second), Duration.zero);
    });
  });
}
