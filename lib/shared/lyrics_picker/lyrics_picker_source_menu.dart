import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import 'lyrics_picker_marquee_label.dart';
import 'lyrics_picker_result_sources.dart';
import '../icons/app_icons.dart';

/// Width of the chip, fixed so the query field beside it never moves.
const double lyricsPickerSourceChipWidth = 200;

/// The source filter of the Choose lyrics dialog: a fixed-width chip that opens
/// a menu with "All sources" and one item per source. [sources] are provider
/// ids with their result counts, in the order of the results; [selected] is
/// the filtered id, or `null` for all. With fewer than two sources the chip is
/// disabled and reads "All sources".
class LyricsPickerSourceMenu extends StatefulWidget {
  const LyricsPickerSourceMenu({
    super.key,
    required this.sources,
    required this.providerNames,
    required this.selected,
    required this.onSelected,
  });

  final List<({String id, int count})> sources;

  /// Display name by provider id.
  final Map<String, String> providerNames;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  State<LyricsPickerSourceMenu> createState() => _LyricsPickerSourceMenuState();
}

class _LyricsPickerSourceMenuState extends State<LyricsPickerSourceMenu> {
  final _controller = MenuController();
  final _chipFocus = FocusNode(debugLabel: 'lyrics source chip');
  // One node per menu item: "All sources" first, then the sources.
  final _itemFocus = <FocusNode>[];
  bool _hovered = false;
  bool _focused = false;
  bool _open = false;

  bool get _enabled => widget.sources.length >= 2;

  /// Whether the last input was a key press (a pointer press clears it). A
  /// mouse click moves focus to the chip without a focus highlight change on
  /// desktop, so the highlight mode cannot tell the two apart.
  bool _lastInputKeyboard = false;

  /// Whether the label may scroll: hovered, or focused after a key press.
  /// Focus that came back after a mouse click does not count.
  bool get _active => _hovered || (_focused && _lastInputKeyboard);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _chipFocus.dispose();
    for (final n in _itemFocus) {
      n.dispose();
    }
    super.dispose();
  }

  void _setKeyboard(bool value) {
    if (_lastInputKeyboard == value) return;
    _lastInputKeyboard = value;
    if (_focused && mounted) setState(() {});
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _setKeyboard(true);
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _setKeyboard(false);
  }

  void _syncItemNodes(int count) {
    while (_itemFocus.length < count) {
      _itemFocus.add(FocusNode(debugLabel: 'lyrics source item'));
    }
    while (_itemFocus.length > count) {
      _itemFocus.removeLast().dispose();
    }
  }

  int _selectedIndex(String? filter) {
    final i = widget.sources.indexWhere((s) => s.id == filter);
    return i < 0 ? 0 : i + 1;
  }

  void _toggle() {
    if (_controller.isOpen) {
      _controller.close();
    } else {
      _controller.open();
    }
  }

  void _focusCurrentItem(String? filter) {
    final index = _selectedIndex(filter);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && index < _itemFocus.length && _controller.isOpen) {
        _itemFocus[index].requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sources = widget.sources;
    final filter = effectiveSourceFilter(widget.selected, sources);
    final filtered = _enabled && filter != null;
    final filterName = filtered ? widget.providerNames[filter] ?? filter : null;
    final label =
        filterName ??
        (_enabled
            ? l10n.lyricsPickerAllSources(sources.length)
            : l10n.lyricsPickerSourceMenuAll);
    final total = sources.fold<int>(0, (n, s) => n + s.count);
    _syncItemNodes(_enabled ? sources.length + 1 : 0);

    final textStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: filtered ? scheme.onSecondaryContainer : null);
    final chip = Semantics(
      label: l10n.lyricsPickerSourceFilterLabel(label),
      button: true,
      enabled: _enabled,
      focusable: _enabled,
      focused: _focused,
      excludeSemantics: true,
      onTap: _enabled ? _toggle : null,
      child: Tooltip(
        // Shows the full name of a filtered source, never over the open menu.
        message: filtered && !_open ? filterName! : '',
        child: SizedBox(
          width: lyricsPickerSourceChipWidth,
          // At least as tall as the dense field; grows with the text scale.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: OutlinedButton(
              focusNode: _chipFocus,
              onPressed: _enabled ? _toggle : null,
              onHover: (h) => setState(() => _hovered = h),
              onFocusChange: (f) => setState(() => _focused = f),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.only(left: 12, right: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: filtered ? scheme.secondaryContainer : null,
                side: filtered ? BorderSide.none : null,
                alignment: Alignment.centerLeft,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LyricsPickerMarqueeLabel(
                      text: label,
                      active: _active,
                      style: textStyle,
                    ),
                  ),
                  Icon(
                    AppIcons.dropDown,
                    color: filtered ? scheme.onSecondaryContainer : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!_enabled) return chip;
    return MenuAnchor(
      controller: _controller,
      consumeOutsideTap: true,
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(320, double.infinity)),
      ),
      onOpen: () {
        setState(() => _open = true);
        _focusCurrentItem(filter);
      },
      onClose: () {
        if (!mounted) return;
        setState(() => _open = false);
      },
      menuChildren: [
        _item(
          index: 0,
          name: l10n.lyricsPickerSourceMenuAll,
          count: total,
          current: filter == null,
          value: null,
        ),
        for (var i = 0; i < sources.length; i++)
          _item(
            index: i + 1,
            name: widget.providerNames[sources[i].id] ?? sources[i].id,
            count: sources[i].count,
            current: filter == sources[i].id,
            value: sources[i].id,
          ),
      ],
      child: chip,
    );
  }

  Widget _item({
    required int index,
    required String name,
    required int count,
    required bool current,
    required String? value,
  }) {
    return MenuItemButton(
      focusNode: _itemFocus[index],
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, 44)),
      ),
      leadingIcon: current
          ? const Icon(AppIcons.check, size: 20)
          : const SizedBox(width: 20, height: 20),
      trailingIcon: Text('$count'),
      onPressed: () => widget.onSelected(value),
      // The cap is in logical pixels: at a large text scale the menu grows
      // past its 320 px maximum, which is accepted. It keeps a long name
      // wrapping instead of widening the menu.
      child: Semantics(
        selected: current,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 208),
          child: Text(name, softWrap: true),
        ),
      ),
    );
  }
}
