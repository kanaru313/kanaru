import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
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
import 'setting_card.dart';
import 'settings_page_scaffold.dart';
import 'settings_section.dart';

final _log = Logger('appearance_fonts_page');

class AppearanceFontsPage extends ConsumerStatefulWidget {
  const AppearanceFontsPage({super.key});

  @override
  ConsumerState<AppearanceFontsPage> createState() => _AppearanceFontsPageState();
}

class _AppearanceFontsPageState extends ConsumerState<AppearanceFontsPage> {
  @override
  void initState() {
    super.initState();
    _preloadActiveFont();
  }

  /// Ensure active custom font is registered with the engine without eagerly
  /// loading every single imported custom font into memory.
  Future<void> _preloadActiveFont() async {
    final activeFontId = ref.read(settingsProvider).display.fontId;
    if (isCustomFontId(activeFontId)) {
      final loader = ref.read(dynamicFontLoaderProvider);
      final storage = ref.read(fontStorageServiceProvider);
      try {
        await loader.ensureLoaded(activeFontId, storage);
      } catch (e, st) {
        _log.warning('Could not preload active custom font "$activeFontId"', e, st);
      }
    }
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
    } catch (e, st) {
      _log.warning('Failed to load font "$fontId" for selection', e, st);
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
    } catch (e, st) {
      _log.warning('Failed to import custom font', e, st);
      if (mounted) _error(context.l10n.customFontImportFailed);
    }
  }

  Future<void> _download(CatalogFontItem font) async {
    try {
      await ref.read(fontDownloadNotifierProvider.notifier).downloadFont(font);
    } catch (e, st) {
      _log.warning('Failed to download font "${font.id}"', e, st);
      if (mounted) _error(context.l10n.fontDownloadFailed(font.label));
    }
  }

  Future<void> _deleteCatalog(String fontId) async {
    try {
      await ref
          .read(installedCatalogFontsProvider.notifier)
          .deleteCatalogFont(fontId);
    } catch (e, st) {
      _log.warning('Failed to delete catalog font "$fontId"', e, st);
      if (mounted) _error(context.l10n.fontLoadFailed(fontId));
    }
  }

  Future<void> _deleteCustom(CustomFontItem font) async {
    final confirmed = await confirmDeleteCustomFont(context, font.label);
    if (!confirmed || !mounted) return;
    try {
      await ref.read(customFontsProvider.notifier).deleteFont(font.id);
    } catch (e, st) {
      _log.warning('Failed to delete custom font "${font.id}"', e, st);
      if (mounted) _error(context.l10n.fontLoadFailed(font.label));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final selectedFontId = ref.watch(settingsProvider).display.fontId;
    final installedCatalog = ref.watch(installedCatalogFontsProvider);
    final customFonts = ref.watch(customFontsProvider);
    final downloading = ref.watch(fontDownloadNotifierProvider);

    final sortedCatalogFonts = [
      ...catalogFontsManifest.where((f) => installedCatalog.contains(f.id)),
      ...catalogFontsManifest.where((f) => !installedCatalog.contains(f.id)),
    ];

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
        SettingsSection(
          title: l10n.settingsFontGroupBuiltIn,
          children: [
            for (final font in builtInAppFonts)
              SettingCard(
                child: FontCatalogTile(
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
              ),
          ],
        ),
        if (customFonts.isNotEmpty)
          SettingsSection(
            title: l10n.settingsFontGroupCustom,
            children: [
              for (final custom in customFonts)
                SettingCard(
                  child: FontCatalogTile(
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
                ),
            ],
          ),
        SettingsSection(
          title: l10n.settingsFontGroupCatalog,
          children: [
            for (final font in sortedCatalogFonts)
              SettingCard(
                child: FontCatalogTile(
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
                  canDelete:
                      installedCatalog.contains(font.id) && selectedFontId != font.id,
                  onSelect: () => _select(font.id, font.label),
                  onDownload: () => _download(font),
                  onDelete: () => _deleteCatalog(font.id),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
