import 'dart:math';

import 'package:archive/archive.dart';

/// Thrown by [PluginCappedOutput] when decoding produces more than its cap.
class PluginOutputOverrun implements Exception {
  const PluginOutputOverrun();
}

/// In-memory output that refuses, before storing, any byte past [cap].
class PluginCappedOutput extends OutputMemoryStream {
  PluginCappedOutput(this.cap) : super(size: max(1, cap));

  final int cap;

  void _room(int count) {
    if (length + count > cap) throw const PluginOutputOverrun();
  }

  @override
  void writeByte(int value) {
    _room(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _room(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _room(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _room(count);
    super.writeBackReference(distance, count);
  }
}
