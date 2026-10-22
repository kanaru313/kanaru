import 'package:flutter/services.dart';

/// The runner's side of "open these files": the C++ application hands files
/// from the command line and from "Open with" to Dart through this channel.
///
/// Files that arrive before Dart is listening wait in the runner. [start]
/// asks for them once the handler is in place, so none is lost and none is
/// delivered twice.
class OpenFilesChannel {
  OpenFilesChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'io.github.kanaru313.kanaru/open_files';

  final MethodChannel _channel;

  /// Starts listening: [onOpen] gets the files of every later `openFiles`
  /// call. Returns the files that arrived before this call (usually the ones
  /// the app was launched with), which [onOpen] does not receive.
  ///
  /// The handler is set before the pending files are requested; the runner
  /// switches to direct delivery when it answers that request, so a call sent
  /// right after cannot fall between the two. Without a runner on the other
  /// side (tests, other platforms) there is nothing pending: returns `[]`.
  Future<List<String>> start(void Function(List<String> paths) onOpen) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFiles') onOpen(_strings(call.arguments));
      return null;
    });
    try {
      return _strings(await _channel.invokeMethod<Object?>('takePendingFiles'));
    } on MissingPluginException {
      return const [];
    }
  }

  static List<String> _strings(Object? value) =>
      value is List ? [...value.whereType<String>()] : const [];
}
