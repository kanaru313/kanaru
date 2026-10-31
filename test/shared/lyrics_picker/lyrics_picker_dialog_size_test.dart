import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/shared/lyrics_picker/lyrics_picker_dialog_size.dart';

void main() {
  test('height is 85 percent of the window, capped at 720', () {
    expect(lyricsPickerContentHeight(900), 720);
    expect(lyricsPickerContentHeight(2000), 720);
    expect(lyricsPickerContentHeight(800), closeTo(680, 0.001));
    expect(lyricsPickerContentHeight(600), closeTo(510, 0.001));
  });

  test('height never goes under the 440 floor', () {
    expect(lyricsPickerContentHeight(400), 440);
    expect(lyricsPickerContentHeight(0), 440);
  });
}
