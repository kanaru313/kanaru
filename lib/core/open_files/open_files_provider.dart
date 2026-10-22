import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'open_files_channel.dart';
import 'open_files_service.dart';

final openFilesServiceProvider = Provider<OpenFilesService>(
  OpenFilesService.new,
);

final _log = Logger('open_files');

/// Starts playing the files the runner hands over: the ones the app was
/// launched with and every later "open" from a second launch. Linux only.
/// Call after the first frame. Never throws; a failure is logged.
Future<void> startOpenFiles(ProviderContainer container) async {
  if (!Platform.isLinux) return;
  final service = container.read(openFilesServiceProvider);
  Future<void> open(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await service.open(paths);
    } on Object catch (error, stack) {
      _log.warning('Could not open the files', error, stack);
    }
  }

  try {
    final pending = await OpenFilesChannel().start(
      (paths) => unawaited(open(paths)),
    );
    await open(pending);
  } on Object catch (error, stack) {
    _log.warning('Open-files channel not started', error, stack);
  }
}
