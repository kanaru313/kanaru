import '../lyrics/plugins/store/plugin_install_id.dart';

/// Which service translates: the install id of a translate plugin (`plugin-`
/// and 12 characters). It is what the cache `provider` column and the
/// settings store. Whether a plugin id is still installed is a different
/// question: see `effectiveTranslationServiceProvider`.
extension type const TranslationServiceId._(String value) {
  /// [value] when it has the shape of a plugin id; else null.
  static TranslationServiceId? tryParse(Object? value) {
    if (value is! String) return null;
    if (pluginInstallIdPattern.hasMatch(value)) {
      return TranslationServiceId._(value);
    }
    return null;
  }
}
