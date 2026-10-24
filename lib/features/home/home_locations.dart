import '../../core/database/home_windows.dart';

/// Location of the Home page itself.
///
/// The same text as `AppDestination.home.path`, repeated on purpose: features
/// cannot import `app/`. A test keeps the two equal.
const homePath = '/home';

/// Location of the full "recently added" list opened on [window].
String homeRecentlyAddedLocation(HomeAddedWindow window) =>
    '$homePath/recently-added?window=${window.slug}';

/// Location of the full "lost memories" list.
const homeMemoriesLocation = '$homePath/memories';

/// Location of the full "recent albums" list.
const homeRecentAlbumsLocation = '$homePath/recent-albums';

/// Location of the full "recent artists" list.
const homeRecentArtistsLocation = '$homePath/recent-artists';
