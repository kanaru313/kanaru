import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kanaru/core/track_details/release_date.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/l10n/app_localizations_vi.dart';
import 'package:kanaru/shared/song_modal/info/release_date_chips.dart';

final _now = DateTime(2026, 10, 31);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('vi');
  });

  final en = AppLocalizationsEn();

  test('a full date reads out and counts the years', () {
    expect(
      releaseDateChipLabels(
        en,
        const ReleaseDate(year: 2008, month: 11, day: 14),
        now: _now,
      ),
      ['Nov 14, 2008', '18 years ago'],
    );
  });

  test('year and month keep that precision', () {
    expect(
      releaseDateChipLabels(
        en,
        const ReleaseDate(year: 2019, month: 7),
        now: _now,
      ),
      ['Jul 2019', '7 years ago'],
    );
  });

  test('a year alone adds only the years-ago chip', () {
    expect(
      releaseDateChipLabels(en, const ReleaseDate(year: 2019), now: _now),
      ['7 years ago'],
    );
  });

  test('this year, one year ago and the future', () {
    expect(
      releaseDateChipLabels(en, const ReleaseDate(year: 2026), now: _now),
      ['this year'],
    );
    expect(
      releaseDateChipLabels(en, const ReleaseDate(year: 2025), now: _now),
      ['1 year ago'],
    );
    expect(
      releaseDateChipLabels(en, const ReleaseDate(year: 2030), now: _now),
      isEmpty,
    );
  });

  test('Vietnamese has the plural too', () {
    expect(
      releaseDateChipLabels(
        AppLocalizationsVi(),
        const ReleaseDate(year: 2026),
        now: _now,
      ),
      ['năm nay'],
    );
  });
}
