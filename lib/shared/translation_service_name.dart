import '../core/lyrics_translation/translation_service.dart';
import '../core/lyrics_translation/translation_service_names.dart';
import '../l10n/l10n.dart';

/// What [service] is called on screen. Google is a brand name; a plugin is
/// shown by its name, with "(plugin)" when that name is a built-in service's
/// (so a plugin called "Google" never passes for Google) and "(removed)"
/// once uninstalled. [plugins] is `translationPluginInfosProvider`. A plugin
/// not in it is shown by its id.
String translationServiceName(
  AppLocalizations l10n,
  Map<String, TranslationPluginInfo> plugins,
  TranslationServiceId service,
) {
  if (service.isGoogle) return 'Google';
  final info = plugins[service.value];
  if (info == null) return service.value;
  var name = info.name;
  if (info.shadowsBuiltIn) name = l10n.translationServicePluginSuffix(name);
  if (info.isRemoved) name = l10n.translationServiceRemovedSuffix(name);
  return name;
}
