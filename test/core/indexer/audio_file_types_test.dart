import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/audio_file_types.dart';

void main() {
  test('recognizes audio extensions in any case', () {
    expect(isAudioFile('/a/song.FLAC'), isTrue);
    expect(isAudioFile('/a/song.opus'), isTrue);
    expect(isAudioFile('/a/cover.jpg'), isFalse);
    expect(isAudioFile('/a/flac'), isFalse);
  });
}
