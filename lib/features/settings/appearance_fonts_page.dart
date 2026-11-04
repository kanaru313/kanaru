import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/fonts/custom_font_providers.dart';
import '../../core/fonts/custom_font_service.dart';
import '../../core/fonts/font_catalog_manifest.dart';
import '../../core/fonts/font_download_notifier.dart';
import '../../core/fonts/font_providers.dart';
import '../../core/fonts/installed_catalog_fonts_provider.dart';
import '../../core/settings/app_font.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../../shared/icons/app_icons.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'custom_font_dialogs.dart';
import 'font_catalog_tile.dart';
import 'settings_page_scaffold.dart';

class AppearanceFontsPage extends ConsumerStatefulWidget {
  const AppearanceFontsPage({super.key});

  @override
  ConsumerState<AppearanceFontsPage> createState() => _AppearanceFontsPageState();
}

class _AppearanceFontsPageState extends ConsumerState<AppearanceFontsPage> {
  @override
  void initState() {
    super.initState();
    _preloadCustomFonts();
  }

  /// Custom rows preview with the real font, so register them when the page
  /// opens (catalog rows use SVG and need nothing).
  Future<void> _preloadCustomFonts() async {
    final loader = ref.read(dynamicFontLoaderProvider);
    final storage = ref.read(fontStorageServiceProvider);
    await loader.loadAllCustomFonts(storage);
    if (mounted) setState(() {});
  }

  void _error(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(kind: AppSnackBarKind.error, title: title),
    );
  }

  Future<void> _select(String fontId, String label) async {
    try {
      // Built-in fonts: no-op. Installed fonts: make sure they are registered
      // before the theme starts using the family.
      await ref
          .read(dynamicFontLoaderProvider)
          .ensureLoaded(fontId, ref.read(fontStorageServiceProvider));
    } catch (_) {
      if (mounted) _error(context.l10n.fontLoadFailed(label));
      return;
    }
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    ref
        .read(settingsProvider.notifier)
        .setDisplay(settings.display.copyWith(fontId: fontId));
  }

  Future<void> _import() async {
    final confirmed = await confirmCustomFontDisclaimer(context);
    if (!confirmed || !mounted) return;
    try {
      await ref.read(customFontsProvider.notifier).importFromPicker();
      // The new font appears in the list; the user taps it to apply it.
    } catch (_) {
      if (mounted) _error(context.l10n.customFontImportFailed);
    }
  }

  Future<void> _download(CatalogFontItem font) async {
    try {
      await ref.read(fontDownloadNotifierProvider.notifier).downloadFont(font);
    } catch (_) {
      if (mounted) _error(context.l10n.fontDownloadFailed(font.label));
    }
  }

  Future<void> _deleteCatalog(String fontId) =>
      ref.read(installedCatalogFontsProvider.notifier).deleteCatalogFont(fontId);

  Future<void> _deleteCustom(CustomFontItem font) async {
    final confirmed = await confirmDeleteCustomFont(context, font.label);
    if (!confirmed || !mounted) return;
    await ref.read(customFontsProvider.notifier).deleteFont(font.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final selectedFontId = ref.watch(settingsProvider).display.fontId;
    final installedCatalog = ref.watch(installedCatalogFontsProvider);
    final customFonts = ref.watch(customFontsProvider);
    final downloading = ref.watch(fontDownloadNotifierProvider);

    return SettingsPageScaffold(
      title: l10n.settingsAppearanceFontsTitle,
      actions: [
        IconButton(
          tooltip: l10n.customFontImportTooltip,
          icon: const Icon(AppIcons.add),
          onPressed: _import,
        ),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.settingsAppearanceFontsSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 1. Built-in fonts
        for (final font in builtInAppFonts)
          FontCatalogTile(
            key: ValueKey(font.id),
            id: font.id,
            label: font.id == systemFontId ? l10n.settingsFontSystem : font.label,
            previewSvgAsset: font.id == systemFontId
                ? null
                : 'assets/font_previews/${font.id}.svg',
            family: font.family,
            isSelected: selectedFontId == font.id,
            isInstalled: true,
            isDownloading: false,
            onSelect: () => _select(font.id, font.label),
          ),

        // 2. Custom (BYOF) fonts
        for (final custom in customFonts)
          FontCatalogTile(
            key: ValueKey(custom.id),
            id: custom.id,
            label: custom.label,
            family: custom.id,
            isSelected: selectedFontId == custom.id,
            isInstalled: true,
            isDownloading: false,
            canDelete: selectedFontId != custom.id,
            onSelect: () => _select(custom.id, custom.label),
            onDelete: () => _deleteCustom(custom),
          ),

        // 3. Catalog fonts
        for (final font in catalogFontsManifest)
          FontCatalogTile(
            key: ValueKey(font.id),
            id: font.id,
            label: font.label,
            previewSvgAsset: font.previewSvgAsset,
            family: font.family,
            formattedSize: font.formattedSize,
            isSelected: selectedFontId == font.id,
            isInstalled: installedCatalog.contains(font.id),
            isDownloading: downloading.containsKey(font.id),
            downloadProgress: downloading[font.id],
            canDelete: installedCatalog.contains(font.id) && selectedFontId != font.id,
            onSelect: () => _select(font.id, font.label),
            onDownload: () => _download(font),
            onDelete: () => _deleteCatalog(font.id),
          ),
      ],
    );
  }
}
