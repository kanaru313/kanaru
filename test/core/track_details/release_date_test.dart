import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/track_details/release_date.dart';

void main() {
  ReleaseDate? parse(String raw) => parseReleaseDate(raw);

  test('accepts the dashed and the bare forms', () {
    const full = ReleaseDate(year: 2019, month: 7, day: 15);
    expect(parse('2019-07-15'), full);
    expect(parse('20190715'), full);
    expect(parse('2019-07'), const ReleaseDate(year: 2019, month: 7));
    expect(parse('201907'), const ReleaseDate(year: 2019, month: 7));
    expect(parse('2019'), const ReleaseDate(year: 2019));
    expect(parse(' 2019-07-15 '), full);
  });

  test('ignores a time after T or a space', () {
    const full = ReleaseDate(year: 2019, month: 7, day: 15);
    expect(parse('2019-07-15T10:20:30Z'), full);
    expect(parse('2019-07-15 10:20'), full);
    expect(parse('20190715T102030'), full);
    expect(parse('2019T10'), const ReleaseDate(year: 2019));
  });

  test('mixed separators keep only the year', () {
    expect(parse('2019-0715'), const ReleaseDate(year: 2019));
    expect(parse('201907-15'), const ReleaseDate(year: 2019));
    expect(parse('2019/07/15'), const ReleaseDate(year: 2019));
  });

  test('an invalid month keeps the year, an invalid day the month', () {
    expect(parse('2019-13-01'), const ReleaseDate(year: 2019));
    expect(parse('2019-00-10'), const ReleaseDate(year: 2019));
    expect(parse('2019-02-30'), const ReleaseDate(year: 2019, month: 2));
    expect(parse('2019-04-31'), const ReleaseDate(year: 2019, month: 4));
    expect(parse('2019-07-00'), const ReleaseDate(year: 2019, month: 7));
  });

  test('leap days are valid only in leap years', () {
    expect(
      parse('2020-02-29'),
      const ReleaseDate(year: 2020, month: 2, day: 29),
    );
    expect(parse('2019-02-29'), const ReleaseDate(year: 2019, month: 2));
    expect(parse('1900-02-29'), const ReleaseDate(year: 1900, month: 2));
    expect(
      parse('2000-02-29'),
      const ReleaseDate(year: 2000, month: 2, day: 29),
    );
    expect(
      parse('2019-12-31'),
      const ReleaseDate(year: 2019, month: 12, day: 31),
    );
  });

  test('no four leading digits or year 0000 gives null', () {
    for (final raw in ['', 'May 2019', '99', '0000', '0000-01-01', '年年年年']) {
      expect(parse(raw), isNull, reason: raw);
    }
  });
}
