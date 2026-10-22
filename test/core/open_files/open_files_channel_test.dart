import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/open_files/open_files_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const name = OpenFilesChannel.channelName;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel(name), null);
    messenger.setMockMessageHandler(name, null);
  });

  test('returns the pending files', () async {
    messenger.setMockMethodCallHandler(const MethodChannel(name), (call) async {
      expect(call.method, 'takePendingFiles');
      return ['/a.flac', '/b.mp3'];
    });

    final pending = await OpenFilesChannel().start((_) {});

    expect(pending, ['/a.flac', '/b.mp3']);
  });

  test('is listening before the pending files are requested', () async {
    final opened = <List<String>>[];
    messenger.setMockMethodCallHandler(const MethodChannel(name), (call) async {
      // The runner switches to direct delivery while answering, so an open
      // can arrive right after, before the answer is processed.
      await messenger.handlePlatformMessage(
        name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('openFiles', ['/late.flac']),
        ),
        (_) {},
      );
      return <String>[];
    });

    final pending = await OpenFilesChannel().start(opened.add);

    expect(pending, isEmpty);
    expect(opened, [
      ['/late.flac'],
    ]);
  });

  test('ignores arguments that are not strings', () async {
    final opened = <List<String>>[];
    await OpenFilesChannel().start(opened.add);
    await messenger.handlePlatformMessage(
      name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('openFiles', ['/a.flac', 3, null]),
      ),
      (_) {},
    );

    expect(opened, [
      ['/a.flac'],
    ]);
  });

  test('without a runner there is nothing pending', () async {
    expect(await OpenFilesChannel().start((_) {}), isEmpty);
  });
}
