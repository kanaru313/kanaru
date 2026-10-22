import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The clock the History page reads "today" from. Tests override it.
final historyNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);
