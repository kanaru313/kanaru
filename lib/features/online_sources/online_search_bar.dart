import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';

/// The search field and its button. [onSearch] runs on the button or Enter
/// only; typing alone calls nothing.
class OnlineSearchBar extends StatefulWidget {
  const OnlineSearchBar({super.key, required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  State<OnlineSearchBar> createState() => _OnlineSearchBarState();
}

class _OnlineSearchBarState extends State<OnlineSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => widget.onSearch(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: l10n.onlineSearchHint,
                prefixIcon: const Icon(AppIcons.search),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _submit,
            child: Text(l10n.onlineSearchButton),
          ),
        ],
      ),
    );
  }
}
