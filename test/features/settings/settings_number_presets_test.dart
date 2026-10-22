import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/settings/settings_number_presets.dart';
import 'package:kanaru/l10n/l10n.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final vi = lookupAppLocalizations(const Locale('vi'));

  test('a stored value outside the presets is added in order', () {
    final options = presetOptions(
      minFileSizePresetsKb,
      300,
      (kb) => formatFileSizeKb(en, kb),
    );

    expect(
      [for (final o in options) o.value],
      [0, 100, 300, 500, 1024, 2048, 5120],
    );
    expect(options[2].label, '300 KB');
  });

  test('a preset value adds nothing', () {
    final options = presetOptions(fadePresetsMs, 200, (ms) => formatMs(en, ms));

    expect(options, hasLength(fadePresetsMs.length));
  });

  test('every default of the options is one of its presets', () {
    expect(minFileSizePresetsKb, contains(0));
    expect(minDurationPresetsSeconds, contains(0));
    expect(crossfadePresetsSeconds, contains(0));
    expect(fadePresetsMs, contains(0));
    expect(listenMinutesPresets, contains(4));
    expect(listenPercentPresets, contains(50));
    expect(fontScalePresets, contains(1.0));
  });

  test('formats in English', () {
    expect(formatFileSizeKb(en, 0), 'Off');
    expect(formatFileSizeKb(en, 100), '100 KB');
    expect(formatFileSizeKb(en, 1024), '1 MB');
    expect(formatFileSizeKb(en, 1536), '1.5 MB');
    expect(formatSeconds(en, 30), '30 s');
    expect(formatMs(en, 0), 'Off');
    expect(formatMs(en, 300), '300 ms');
    expect(formatPercent(en, 50), '50%');
    expect(formatScale(en, 1.25), '125%');
    expect(en.settingsUnitMinutes(4), '4 min');
  });

  test('formats in Vietnamese', () {
    expect(formatFileSizeKb(vi, 0), 'Tắt');
    expect(formatFileSizeKb(vi, 1536), '1,5 MB');
    expect(formatSeconds(vi, 30), '30 giây');
    expect(vi.settingsUnitMinutes(4), '4 phút');
  });
}
