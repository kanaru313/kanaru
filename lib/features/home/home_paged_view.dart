import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/empty_state.dart';
import 'home_paged_list.dart';

/// Body of a full list page: picks what to show for the [state] of a
/// [HomePagedList] (nothing while the first page reads, the failure sentence,
/// the empty sentence, or the rows) and asks for the next page once the user
/// is within one screen of the end.
class HomePagedView<T> extends StatefulWidget {
  const HomePagedView({
    super.key,
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
    required this.emptyIcon,
    required this.emptyText,
    required this.builder,
  });

  final HomePagedState<T> state;
  final VoidCallback onLoadMore;

  /// Reads again after a failed read; offered under the failure sentence.
  final VoidCallback onRetry;
  final IconData emptyIcon;

  /// The one sentence shown when a finished read has no rows.
  final String emptyText;

  /// The scrolling list over [HomePagedState.rows]; it must attach the
  /// controller so the view can watch the position.
  final Widget Function(
    BuildContext context,
    ScrollController controller,
    List<T> rows,
  )
  builder;

  @override
  State<HomePagedView<T>> createState() => _HomePagedViewState<T>();
}

class _HomePagedViewState<T> extends State<HomePagedView<T>> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkEnd);
    _checkEndAfterFrame();
  }

  @override
  void didUpdateWidget(HomePagedView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // More rows, or a finished read, may leave the end within reach again
    // (a short first page on a tall window).
    _checkEndAfterFrame();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkEndAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) => _checkEnd());
  }

  void _checkEnd() {
    if (!mounted || !_controller.hasClients) return;
    final state = widget.state;
    if (state.loading || state.done || state.failed) return;
    final position = _controller.position;
    if (position.extentAfter < position.viewportDimension) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.rows.isEmpty) {
      if (state.failed) return Center(child: _failure(context));
      if (!state.done) return const SizedBox.shrink();
      return EmptyState(icon: widget.emptyIcon, title: widget.emptyText);
    }
    // The list keeps its slot, so a failure row appearing under it (a failed
    // later read keeps the rows and offers a retry) does not reset the scroll.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: widget.builder(context, _controller, state.rows)),
        if (state.failed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _failure(context),
          ),
      ],
    );
  }

  /// The failure sentence with a text button to read again.
  Widget _failure(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.homeLoadFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(onPressed: widget.onRetry, child: Text(l10n.homeRetry)),
      ],
    );
  }
}
