import 'package:material_ui/material_ui.dart';

import '../icons/app_icons.dart';

/// What a snackbar reports; picks its icon and icon color.
enum AppSnackBarKind { success, info, warning, error }

/// Status icon + title (+ details): the one layout of every snackbar.
///
/// With [details] the icon sits at the top, beside a bold title and a quieter
/// details line. Without, the title stands alone and the icon is centered on it.
class AppSnackBarContent extends StatelessWidget {
  const AppSnackBarContent({
    super.key,
    required this.kind,
    required this.title,
    this.details,
  });

  final AppSnackBarKind kind;
  final String title;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, iconColor) = switch (kind) {
      AppSnackBarKind.success => (AppIcons.success, colors.primary),
      AppSnackBarKind.info => (AppIcons.info, colors.onSurfaceVariant),
      AppSnackBarKind.warning => (AppIcons.warningRounded, colors.tertiary),
      AppSnackBarKind.error => (AppIcons.errorRounded, colors.error),
    };
    final details = this.details;

    return Row(
      crossAxisAlignment: details == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (details != null) ...[
                const SizedBox(height: 2),
                Text(
                  details,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The app's snackbar: frame from the theme, content from [AppSnackBarContent].
///
/// Every other argument goes to [SnackBar] unchanged. [persist] stays nullable:
/// null means "persist when there is an action", the [SnackBar] default.
SnackBar appSnackBar({
  Key? key,
  required AppSnackBarKind kind,
  required String title,
  String? details,
  SnackBarAction? action,
  Duration duration = const Duration(milliseconds: 4000),
  bool? persist,
  VoidCallback? onVisible,
}) => SnackBar(
  key: key,
  content: AppSnackBarContent(kind: kind, title: title, details: details),
  action: action,
  duration: duration,
  persist: persist,
  onVisible: onVisible,
);
