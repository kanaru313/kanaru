/// Size and count caps for a plugin package. Every cap applies to the
/// declared size and to what inflating really produces.
const maxPluginPackageBytes = 5 * 1024 * 1024;
const maxPluginZipEntries = 50;
const maxPluginUnpackedBytes = 5 * 1024 * 1024;
const maxPluginScriptBytes = 1024 * 1024;
const maxPluginManifestBytes = 64 * 1024;
const maxPluginIconBytes = 64 * 1024;
const maxPluginIconSide = 256;
