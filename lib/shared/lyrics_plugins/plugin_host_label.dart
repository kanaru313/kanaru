import '../../l10n/l10n.dart';

/// How a host entry of a plugin reads to the user: a wildcard `*.x` is "Any
/// subdomain of x" (the plugin may reach one level of subdomain), a plain
/// host is shown as it is.
String pluginHostLabel(AppLocalizations l10n, String host) =>
    host.startsWith('*.')
    ? l10n.pluginInfoHostAnySubdomain(host.substring(2))
    : host;
