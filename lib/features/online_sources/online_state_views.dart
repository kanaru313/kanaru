import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/sources/source_models.dart';
import '../../core/sources/source_plugin_records.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/lyrics_source_routes.dart';
import '../../shared/online_routes.dart';

/// A centered message with an optional button, the shape of every state of
/// the Online screen that has no list.
class _Message extends StatelessWidget {
  const _Message({required this.lines, this.action});

  final List<Widget> lines;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...lines,
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ),
  );
}

Widget _text(BuildContext context, String text, {bool muted = false}) {
  final theme = Theme.of(context);
  return Text(
    text,
    textAlign: TextAlign.center,
    style: muted
        ? theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.bodyLarge,
  );
}

/// Before any search.
class OnlineIdleView extends StatelessWidget {
  const OnlineIdleView({super.key});

  @override
  Widget build(BuildContext context) =>
      _Message(lines: [_text(context, context.l10n.onlineIdle, muted: true)]);
}

/// While a search runs.
class OnlineLoadingView extends StatelessWidget {
  const OnlineLoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// The search found nothing for [query].
class OnlineEmptyView extends StatelessWidget {
  const OnlineEmptyView({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => _Message(
    lines: [_text(context, context.l10n.onlineEmpty(query), muted: true)],
  );
}

/// The words for a failed search, by kind.
String onlineFailureText(AppLocalizations l10n, SourceFailureKind kind) =>
    switch (kind) {
      SourceFailureKind.auth => l10n.onlineErrorAuth,
      SourceFailureKind.rateLimited => l10n.onlineErrorRateLimited,
      SourceFailureKind.unavailable => l10n.onlineErrorUnavailable,
      SourceFailureKind.network => l10n.onlineErrorNetwork,
      SourceFailureKind.invalidOutput => l10n.onlineErrorInvalidOutput,
      SourceFailureKind.busy => l10n.onlineErrorBusy,
      SourceFailureKind.notConsented ||
      SourceFailureKind.needsConfig ||
      SourceFailureKind.skipped ||
      SourceFailureKind.internal => l10n.onlineErrorInternal,
    };

/// A failed search: the cause by kind, the plugin's own message when it gave
/// one, and Retry. A missing setting opens the plugin page instead.
class OnlineErrorView extends StatelessWidget {
  const OnlineErrorView({
    super.key,
    required this.record,
    required this.kind,
    required this.message,
    required this.onRetry,
  });

  final LyricsPluginRecord record;
  final SourceFailureKind kind;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (kind == SourceFailureKind.needsConfig) {
      return _Message(
        lines: [
          _text(context, l10n.pluginNeedsConfigTitle(record.name)),
          const SizedBox(height: 8),
          _text(context, l10n.onlineNeedsConfigBody, muted: true),
        ],
        action: FilledButton(
          onPressed: () =>
              context.go(onlineSourcePluginRoute(record.installId)),
          child: Text(l10n.pluginOpenConfig),
        ),
      );
    }
    return _Message(
      lines: [
        const Icon(AppIcons.errorOutline, size: 32),
        const SizedBox(height: 8),
        _text(context, onlineFailureText(l10n, kind)),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.onlineErrorPluginMessage(message),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
      action: FilledButton(onPressed: onRetry, child: Text(l10n.onlineRetry)),
    );
  }
}

/// The notice the plugin needs accepted before it may send: names the plugin
/// and its hosts.
class OnlineConsentView extends StatelessWidget {
  const OnlineConsentView({
    super.key,
    required this.record,
    required this.onAccept,
  });

  final LyricsPluginRecord record;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Message(
      lines: [
        Text(
          l10n.onlineConsentTitle(record.name),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _text(
          context,
          l10n.onlineConsentBody(record.name, record.hosts.join(', ')),
        ),
      ],
      action: FilledButton(
        onPressed: onAccept,
        child: Text(l10n.onlineConsentAccept),
      ),
    );
  }
}

/// No source plugin is installed: the way to the plugin store.
class OnlineNoPluginView extends StatelessWidget {
  const OnlineNoPluginView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Message(
      lines: [_text(context, l10n.onlineNoPluginBody)],
      action: FilledButton(
        onPressed: () => context.go(lyricsStoreRoute),
        child: Text(l10n.onlineNoPluginStore),
      ),
    );
  }
}
