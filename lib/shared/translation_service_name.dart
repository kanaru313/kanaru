import '../core/lyrics_translation/translation_service.dart';
import '../core/lyrics_translation/translation_service_names.dart';
import '../l10n/l10n.dart';

/// What [service] is called on screen: the plugin's name, with "(removed)"
/// once uninstalled. [plugins] is `translationPluginInfosProvider`. A plugin
/// not in it is shown by its id.
String translationServiceName(
  AppLocalizations l10n,
  Map<String, TranslationPluginInfo> plugins,
  TranslationServiceId service,
) {
  final info = plugins[service.value];
  if (info == null) return service.value;
  var name = info.name;
  if (info.isRemoved) name = l10n.translationServiceRemovedSuffix(name);
  return name;
}
