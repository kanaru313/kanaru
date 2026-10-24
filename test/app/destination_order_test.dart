import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/core/settings/display_prefs.dart';

void main() {
  group('destinationScreenOrder', () {
    test('contains every AppDestination exactly once', () {
      final counts = <AppDestination, int>{};
      for (final d in destinationScreenOrder) {
        counts[d] = (counts[d] ?? 0) + 1;
      }
      for (final d in AppDestination.values) {
        expect(
          counts[d],
          1,
          reason: '$d should appear exactly once in destinationScreenOrder',
        );
      }
      expect(destinationScreenOrder.length, AppDestination.values.length);
    });

    test('ends with playlists', () {
      expect(destinationScreenOrder.last, AppDestination.playlists);
    });

    test('starts with search then settings', () {
      expect(destinationScreenOrder[0], AppDestination.search);
      expect(destinationScreenOrder[1], AppDestination.settings);
    });

    group('relative order matches visibleSidebarGroups for any tab subset', () {
      void checkSubset(Set<SidebarTab> tabs, String label) {
        test(label, () {
          final visible = visibleSidebarGroups(
            tabs,
          ).expand((g) => g).toList();
          // The relative order of destinations present in both lists must
          // match: hiding a tab only drops it, never reorders the rest.
          final visibleRanks = [
            for (final d in visible) destinationScreenOrder.indexOf(d),
          ];
          final sorted = [...visibleRanks]..sort();
          expect(
            visibleRanks,
            sorted,
            reason:
                'visibleSidebarGroups($tabs) order must be a subsequence '
                'of destinationScreenOrder',
          );
        });
      }

      checkSubset(SidebarTab.values.toSet(), 'all tabs shown');
      checkSubset(<SidebarTab>{}, 'all tabs hidden');
      checkSubset(
        SidebarTab.values.toSet()..remove(SidebarTab.albums),
        'one tab (albums) hidden',
      );
    });
  });

  group('branchDirection', () {
    test('home -> songs is towardsBelow', () {
      expect(
        branchDirection(AppDestination.home, AppDestination.songs),
        BranchDirection.towardsBelow,
      );
    });

    test('songs -> home is towardsAbove', () {
      expect(
        branchDirection(AppDestination.songs, AppDestination.home),
        BranchDirection.towardsAbove,
      );
    });

    test('folders -> queueHistory is towardsBelow', () {
      expect(
        branchDirection(AppDestination.folders, AppDestination.queueHistory),
        BranchDirection.towardsBelow,
      );
    });

    test('history -> playlists is towardsBelow', () {
      expect(
        branchDirection(AppDestination.history, AppDestination.playlists),
        BranchDirection.towardsBelow,
      );
    });

    test('home -> settings is towardsAbove', () {
      expect(
        branchDirection(AppDestination.home, AppDestination.settings),
        BranchDirection.towardsAbove,
      );
    });

    test('search -> settings is towardsBelow', () {
      expect(
        branchDirection(AppDestination.search, AppDestination.settings),
        BranchDirection.towardsBelow,
      );
    });

    test('same destination is none', () {
      for (final d in AppDestination.values) {
        expect(branchDirection(d, d), BranchDirection.none);
      }
    });

    test('a hidden destination still gets a direction', () {
      // Albums has no fixed sidebar spot once its tab is hidden, but its
      // rank in destinationScreenOrder does not depend on visibility.
      expect(
        branchDirection(AppDestination.albums, AppDestination.playlists),
        BranchDirection.towardsBelow,
      );
      expect(
        branchDirection(AppDestination.playlists, AppDestination.albums),
        BranchDirection.towardsAbove,
      );
    });
  });
}
