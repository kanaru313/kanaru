import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/settings_routes.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'settings_focus.dart';
import 'settings_save_warning.dart';

/// The page frame shared by the Settings root and its section pages: a
/// titled page with a scrolling column of at most 720 px, starting with the
/// warning shown when settings cannot be saved.
///
/// [focus] is the anchor a link asked for: when it is set at mount or
/// changes to another anchor, the page scrolls to the target and pulses it.
class SettingsPageScaffold extends StatefulWidget {
  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.focus,
    this.actions,
  });

  final String title;
  final List<Widget> children;
  final SettingsAnchor? focus;
  final List<Widget>? actions;

  @override
  State<SettingsPageScaffold> createState() => _SettingsPageScaffoldState();
}

class _SettingsPageScaffoldState extends State<SettingsPageScaffold> {
  final _registry = SettingsFocusRegistry();
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    final focus = widget.focus;
    if (focus != null) _scheduleFocus(focus);
  }

  @override
  void didUpdateWidget(SettingsPageScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a change to an anchor: the router also rebuilds the page for
    // other reasons (theme), and dropping the parameter must not stop a pulse.
    final focus = widget.focus;
    if (focus != null && focus != oldWidget.focus) _scheduleFocus(focus);
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  void _scheduleFocus(SettingsAnchor anchor) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stripFocusFromUrl(anchor);
      final target = _registry.find(anchor);
      if (target == null) return;
      final reduced = MediaQuery.disableAnimationsOf(context);
      // Fire and forget: a scroll cut short by leaving the page is harmless.
      unawaited(
        Scrollable.ensureVisible(
          target.context,
          alignment: 0.1,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 300),
          curve: Easing.emphasizedDecelerate,
        ),
      );
      _pulseTimer?.cancel();
      _pulseTimer = Timer(settingsFocusSettleDelay, target.highlight);
    });
  }

  /// Makes the URL plain once the link is used, so the same link opens it
  /// again later and a restored branch does not pulse. Skipped when the
  /// router is no longer on this page with the parameter.
  void _stripFocusFromUrl(SettingsAnchor anchor) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = router.routerDelegate.currentConfiguration.uri;
    if (uri.path != anchor.page ||
        !uri.queryParameters.containsKey(settingsFocusParam)) {
      return;
    }
    router.go(withoutSettingsFocus(uri.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: widget.title,
      actions: widget.actions,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Keeps rows readable on wide windows.
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              // Stretched so every section starts at the same left edge,
              // whatever its rows' own width. One column, not a builder, so
              // every row is built.
              child: SettingsFocusScope(
                registry: _registry,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const SettingsSaveWarning(), ...widget.children],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
