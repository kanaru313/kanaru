import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/features/library/folders/folder_modal/folder_modal_actions.dart';
import 'package:kanaru/features/library/folders/folder_modal/folder_modal_data.dart';
import 'package:kanaru/features/library/folders/folder_tree.dart';
import 'package:kanaru/l10n/app_localizations_en.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_nav.dart';
import 'package:kanaru/shared/widgets/context_modal/context_modal_spec.dart';

import 'folder_modal_test_support.dart';

final _l10n = AppLocalizationsEn();

class _CallTracker {
  int goToFolder = 0;
  int playAll = 0;
  int shuffle = 0;
  int playAllBelow = 0;
  int addToPlaylist = 0;
  int createPlaylist = 0;
  int openAdvanced = 0;
}

FolderModalHandlers _handlersOf(
  _CallTracker tracker, {
  bool withPlayAllBelow = false,
}) => FolderModalHandlers(
  goToFolder: () => tracker.goToFolder++,
  playAll: () => tracker.playAll++,
  shuffle: () => tracker.shuffle++,
  playAllBelow: withPlayAllBelow ? () => tracker.playAllBelow++ : null,
  addToPlaylist: () => tracker.addToPlaylist++,
  createPlaylist: () => tracker.createPlaylist++,
  showInFileManager: (_) {},
  copyPath: () {},
  excludeFromLibrary: () {},
);

List<List<ContextModalAction>> _sections({
  FolderNode? folder,
  bool direct = false,
  bool showFolder = true,
  bool gone = false,
  FolderModalHandlers? handlers,
  void Function(ContextModalNav)? openAdvanced,
}) {
  final node = folder ?? testFolder;
  final data = FolderModalData(
    folder: node,
    direct: direct,
    showFolder: showFolder,
    gone: gone,
  );
  return folderModalSections(
    _l10n,
    data,
    handlers ?? _handlersOf(_CallTracker()),
    openAdvanced: openAdvanced ?? (_) {},
  );
}

Map<String, ContextModalAction> _byId(
  List<List<ContextModalAction>> sections,
) => {
  for (final s in sections)
    for (final a in s) a.id: a,
};

List<String> _ids(List<List<ContextModalAction>> sections) => [
  for (final s in sections)
    for (final a in s) a.id,
];

void main() {
  test('default rows in order', () {
    final sections = _sections();
    expect(_ids(sections), [
      'folder',
      'play-all',
      'shuffle',
      'add-to-playlist',
      'create-playlist',
      'edit-tags',
      'advanced',
    ]);
  });

  test('Go to folder is omitted when showFolder is false', () {
    final sections = _sections(showFolder: false);
    expect(_ids(sections), [
      'play-all',
      'shuffle',
      'add-to-playlist',
      'create-playlist',
      'edit-tags',
      'advanced',
    ]);
  });

  test('Go to folder subtitle is folder label', () {
    final sections = _sections(folder: makeFolderNode(label: 'Custom / Rock'));
    expect(_byId(sections)['folder']!.subtitle, 'Custom / Rock');
  });

  group('play-all-below', () {
    test('omitted in tree view (direct: false) even with children', () {
      final child = makeFolderNode(path: '/m/Rock/Alt', name: 'Alt');
      final folder = makeFolderNode(children: [child]);
      final sections = _sections(folder: folder, direct: false);
      expect(_ids(sections), isNot(contains('play-all-below')));
    });

    test('omitted in flat view (direct: true) when children are empty', () {
      final folder = makeFolderNode(children: []);
      final sections = _sections(folder: folder, direct: true);
      expect(_ids(sections), isNot(contains('play-all-below')));
    });

    test('present in flat view (direct: true) when folder has children', () {
      final child = makeFolderNode(path: '/m/Rock/Alt', name: 'Alt');
      final folder = makeFolderNode(children: [child]);
      final sections = _sections(folder: folder, direct: true);
      expect(_ids(sections), [
        'folder',
        'play-all',
        'shuffle',
        'play-all-below',
        'add-to-playlist',
        'create-playlist',
        'edit-tags',
        'advanced',
      ]);
    });

    test('enabled when playAllBelow is non-null and not gone', () {
      final tracker = _CallTracker();
      final child = makeFolderNode(path: '/m/Rock/Alt', name: 'Alt');
      final folder = makeFolderNode(children: [child]);
      final sections = _sections(
        folder: folder,
        direct: true,
        handlers: _handlersOf(tracker, withPlayAllBelow: true),
      );
      final action = _byId(sections)['play-all-below']!;
      expect(action.enabled, isTrue);
    });

    test('disabled when playAllBelow is null', () {
      final tracker = _CallTracker();
      final child = makeFolderNode(path: '/m/Rock/Alt', name: 'Alt');
      final folder = makeFolderNode(children: [child]);
      final sections = _sections(
        folder: folder,
        direct: true,
        handlers: _handlersOf(tracker, withPlayAllBelow: false),
      );
      final action = _byId(sections)['play-all-below']!;
      expect(action.enabled, isFalse);
    });
  });

  group('gone state', () {
    test('disables playback and playlist actions when gone is true', () {
      final child = makeFolderNode(path: '/m/Rock/Alt', name: 'Alt');
      final folder = makeFolderNode(children: [child]);
      final tracker = _CallTracker();
      final sections = _sections(
        folder: folder,
        direct: true,
        gone: true,
        handlers: _handlersOf(tracker, withPlayAllBelow: true),
      );
      final byId = _byId(sections);

      expect(byId['play-all']!.enabled, isFalse);
      expect(byId['shuffle']!.enabled, isFalse);
      expect(byId['play-all-below']!.enabled, isFalse);
      expect(byId['add-to-playlist']!.enabled, isFalse);
      expect(byId['create-playlist']!.enabled, isFalse);

      // Navigation and advanced remain enabled
      expect(byId['folder']!.enabled, isTrue);
      expect(byId['advanced']!.enabled, isTrue);
    });

    test('enables playback and playlist actions when gone is false', () {
      final sections = _sections(gone: false);
      final byId = _byId(sections);

      expect(byId['play-all']!.enabled, isTrue);
      expect(byId['shuffle']!.enabled, isTrue);
      expect(byId['add-to-playlist']!.enabled, isTrue);
      expect(byId['create-playlist']!.enabled, isTrue);
    });
  });

  test('action attributes: edit-tags is coming soon, advanced opens page', () {
    final sections = _sections();
    final byId = _byId(sections);

    expect(byId['edit-tags']!.comingSoon, isTrue);
    expect(byId['advanced']!.opensPage, isTrue);
  });

  test('action callbacks close modal and invoke handlers', () {
    final tracker = _CallTracker();
    final child = makeFolderNode(path: '/m/Rock/Alt', name: 'Alt');
    final folder = makeFolderNode(children: [child]);
    var advancedOpened = 0;

    final sections = _sections(
      folder: folder,
      direct: true,
      handlers: _handlersOf(tracker, withPlayAllBelow: true),
      openAdvanced: (_) => advancedOpened++,
    );
    final byId = _byId(sections);

    var closed = 0;
    final nav = ContextModalNav(
      push: (_) {},
      pop: () {},
      close: ([_]) => closed++,
    );

    byId['folder']!.onTap!(nav);
    expect(tracker.goToFolder, 1);
    expect(closed, 1);

    byId['play-all']!.onTap!(nav);
    expect(tracker.playAll, 1);
    expect(closed, 2);

    byId['shuffle']!.onTap!(nav);
    expect(tracker.shuffle, 1);
    expect(closed, 3);

    byId['play-all-below']!.onTap!(nav);
    expect(tracker.playAllBelow, 1);
    expect(closed, 4);

    byId['add-to-playlist']!.onTap!(nav);
    expect(tracker.addToPlaylist, 1);
    expect(closed, 5);

    byId['create-playlist']!.onTap!(nav);
    expect(tracker.createPlaylist, 1);
    expect(closed, 6);

    byId['advanced']!.onTap!(nav);
    expect(advancedOpened, 1);
    // advanced opens a page, so it does not close the modal
    expect(closed, 6);
  });
}
