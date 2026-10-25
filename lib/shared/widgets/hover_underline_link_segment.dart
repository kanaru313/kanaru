import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One piece of a [HoverUnderlineLinks] line: a link when [onTap] is set,
/// plain text otherwise.
class LinkSegment {
  const LinkSegment(this.text, {this.onTap});

  final String text;

  /// Called with the global position of the tap (or the line's bottom-left
  /// for keyboard and semantic activation). Null makes the segment plain.
  final ValueChanged<Offset>? onTap;
}
