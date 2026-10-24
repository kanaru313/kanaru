import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/core/database/home_windows.dart';
import 'package:kanaru/features/home/home_locations.dart';
import 'package:kanaru/shared/library_route_keys.dart';

void main() {
  test('the Home path matches the destination', () {
    expect(homePath, AppDestination.home.path);
  });

  test('the history path matches the destination', () {
    expect(historyPath, AppDestination.history.path);
  });

  test('every window has a location whose slug reads back', () {
    for (final window in HomeAddedWindow.values) {
      final uri = Uri.parse(homeRecentlyAddedLocation(window));
      expect(uri.path, '$homePath/recently-added');
      expect(HomeAddedWindow.fromSlug(uri.queryParameters['window']), window);
    }
  });

  test('an unknown or missing slug is no window', () {
    expect(HomeAddedWindow.fromSlug('xyz'), isNull);
    expect(HomeAddedWindow.fromSlug(null), isNull);
  });

  test('the other locations sit below Home', () {
    expect(homeMemoriesLocation, '/home/memories');
    expect(homeRecentAlbumsLocation, '/home/recent-albums');
    expect(homeRecentArtistsLocation, '/home/recent-artists');
  });
}
