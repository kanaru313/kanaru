/// Paths of the Settings pages. Constants only; the routes that serve them
/// live in `lib/features/settings/` and `lib/app/`.
library;

/// The Settings root: one tile per category.
const settingsRoute = '/settings';

const settingsAppearanceRoute = '$settingsRoute/appearance';
const settingsPlaybackRoute = '$settingsRoute/playback';
const settingsLibraryRoute = '$settingsRoute/library';
const settingsDataRoute = '$settingsRoute/data';
const settingsAboutRoute = '$settingsRoute/about';
