import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/logging/log_level.dart';
import 'package:logging/logging.dart';

void main() {
  Level parse(String? raw) => parseLogLevel(raw, fallback: Level.INFO);

  test('matches level names in any case', () {
    expect(parse('fine'), Level.FINE);
    expect(parse('FINE'), Level.FINE);
    expect(parse('Info'), Level.INFO);
    expect(parse(' shout '), Level.SHOUT);
    expect(parse('all'), Level.ALL);
  });

  test('falls back for missing, empty or unknown values', () {
    expect(parse(null), Level.INFO);
    expect(parse(''), Level.INFO);
    expect(parse('debug'), Level.INFO);
    expect(parseLogLevel('xyz', fallback: Level.ALL), Level.ALL);
  });
}
