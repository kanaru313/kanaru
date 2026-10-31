import 'dart:math' as math;

/// Width of the Choose lyrics dialog content.
const lyricsPickerContentWidth = 840.0;

/// Width of the result list beside the preview.
const lyricsPickerListWidth = 420.0;

const _maxHeight = 720.0;
const _minHeight = 440.0;
const _windowFraction = 0.85;

/// Height of the Choose lyrics dialog content for a window [windowHeight]
/// tall: 85 % of the window, at most 720 px and at least 440 px. A window too
/// small for the minimum makes the dialog scroll instead.
double lyricsPickerContentHeight(double windowHeight) =>
    math.max(_minHeight, math.min(_windowFraction * windowHeight, _maxHeight));
