import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/player/sleep_timer.dart';
import 'sleep_timer_draft.dart';
import 'sleep_timer_running_view.dart';
import 'sleep_timer_setup_view.dart';

/// Opens the sleep timer dialog, centred over the window. It lives on the
/// root navigator, so it covers the whole app whichever button opened it.
Future<void> showSleepTimerDialog(BuildContext context) => showDialog<void>(
  context: context,
  useRootNavigator: true,
  builder: (_) => const SleepTimerDialog(),
);

/// Dialog that sets, shows and changes the sleep timer. It opens on the
/// running timer's controls when one runs, otherwise on the setup tabs.
class SleepTimerDialog extends ConsumerStatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  ConsumerState<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends ConsumerState<SleepTimerDialog> {
  late bool _showRunning = ref.read(sleepTimerProvider).active;
  SleepTimerDraft _draft = const SleepTimerDraft();

  /// The number field is focused when the setup view opens; after the user
  /// picks a tab the focus stays on the tabs.
  bool _focusNumber = true;

  /// Set once the dialog is closing, so the timer turning off in the same
  /// moment (Turn off) does not pop a second route.
  bool _closing = false;

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _change() => setState(() {
    _draft = SleepTimerDraft.fromState(ref.read(sleepTimerProvider));
    _showRunning = false;
    _focusNumber = true;
  });

  @override
  Widget build(BuildContext context) {
    // A timer that ends by itself leaves nothing to show in the running view.
    ref.listen(sleepTimerProvider.select((s) => s.active), (_, active) {
      if (!active &&
          _showRunning &&
          ModalRoute.of(context)?.isCurrent == true) {
        _close();
      }
    });
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        // A short window scrolls instead of overflowing.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: _showRunning
              ? SleepTimerRunningView(onChange: _change, onClose: _close)
              : SleepTimerSetupView(
                  draft: _draft,
                  onChanged: (d) => setState(() {
                    if (d.tab != _draft.tab) _focusNumber = false;
                    _draft = d;
                  }),
                  autofocusNumber: _focusNumber,
                  onShowRunning: () => setState(() => _showRunning = true),
                  onClose: _close,
                ),
        ),
      ),
    );
  }
}
