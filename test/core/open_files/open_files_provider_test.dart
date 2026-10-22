import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/core/indexer/indexer_providers.dart';
import 'package:kanaru/core/open_files/open_files_channel.dart';
import 'package:kanaru/core/open_files/open_files_provider.dart';
import 'package:kanaru/core/player/player_service.dart';
import 'package:logging/logging.dart';

import '../indexer/fake_tag_reader.dart';
import '../player/fake_audio_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const name = OpenFilesChannel.channelName;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory dir;
  late ProviderContainer container;

  String file(String n) {
    final f = File('${dir.path}/$n')..writeAsStringSync('x');
    return f.path;
  }

  List<String> titles() => [
    for (final t in container.read(playerServiceProvider).queue.tracks) t.title,
  ];

  /// What the runner does when Dart asks: `openFiles` calls sent while the
  /// answer is on its way, then the pending list.
  void runner({
    List<String> early = const [],
    List<String> pending = const [],
  }) {
    messenger.setMockMethodCallHandler(const MethodChannel(name), (call) async {
      expect(call.method, 'takePendingFiles');
      for (final path in early) {
        await messenger.handlePlatformMessage(
          name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('openFiles', [path]),
          ),
          (_) {},
        );
      }
      return pending;
    });
  }

  setUp(() {
    Logger.root.level = Level.OFF;
    dir = Directory(
      Directory.systemTemp
          .createTempSync('kanaru_open_wiring_')
          .resolveSymbolicLinksSync(),
    );
    container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(FakeAudioBackend()),
        tagReaderProvider.overrideWithValue(FakeTagReader()),
      ],
    );
    container.listen(playerServiceProvider, (_, _) {});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel(name), null);
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  test('plays the files that were waiting in the runner', () async {
    runner(pending: [file('a.flac'), file('b.mp3')]);

    await startOpenFiles(container);

    expect(titles(), ['A.FLAC', 'B.MP3']);
  });

  test('an empty pending list does not cancel a file sent during the '
      'handshake', () async {
    runner(early: [file('late.flac')]);

    await startOpenFiles(container);
    // The direct request runs on its own; wait for it to reach the player.
    for (var i = 0; i < 100 && titles().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(titles(), ['LATE.FLAC']);
  });

  test('does nothing, and does not throw, without a runner', () async {
    await startOpenFiles(container);

    expect(titles(), isEmpty);
  });
}
