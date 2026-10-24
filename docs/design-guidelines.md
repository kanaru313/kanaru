# Design guidelines

UI rules as the code implements them today. New screens follow these first; if a rule is wrong for a new case, change the rule here in the same PR.

Related: [code-standards.md](./code-standards.md) (widget conventions), [features.md](./features.md) (requirements by ID).

## Principles

1. **Material 3 everywhere.** Use `material_ui` widgets and theme tokens. No hard-coded colors for text or surfaces.
2. **Library first, player always.** Browsing works without playback; playback controls are visible on every screen where a track can be playing.
3. **Works from the 480 px minimum window to a 4K display.** Layout changes at named breakpoints, not by device type. UI-05 targets 360 px, which is not yet the minimum.
4. **Keyboard and mouse are both first class.** Every action has a key or a visible control; overlays restore focus on close.
5. **Calm motion.** Animations are short and skipped under reduced motion.
6. **Say what is happening.** Empty, loading and "updating" states name the situation (see [States](#states)).

## Theme

| Item | Rule | Source |
|---|---|---|
| Base | Material 3 via `ColorScheme.fromSeed` | `lib/app/theme.dart` |
| Seed color | `#6750A4` (`kanaruSeedColor`), used when the system gives no accent | `lib/app/theme.dart` |
| System accent | `dynamic_color` (`DynamicColorBuilder`) supplies the GTK accent on Linux; the scheme is harmonized with it | `lib/app/app.dart`, `lib/app/theme.dart` |
| Modes | Light, dark, system. Changes apply immediately; the applied appearance is debounced by 600 ms (`appliedAppearanceProvider`) | `core/settings/applied_appearance_provider.dart` |
| AMOLED black | Not built (UI-08) | features.md |
| Artwork color | With "Colors from the cover" on, the playing cover's seed replaces the system accent (`ColorScheme.fromSeed`, tonal spot) in both themes; a gray cover, no cover or nothing playing keeps the system accent. Now Playing gets a gradient of the cover's colors over the surface (text keeps 4.5:1 contrast; a gray cover still tints it). The app's colors change at once (no theme animation, also between light and dark); only the Now Playing gradient fades, over 300 ms (`coverThemeTransition`), at once when the system asks for reduced motion (UI-03) | `lib/app/theme.dart`, `lib/app/app.dart`, `core/cover_colors/playing_cover_palette_provider.dart` |

## Breakpoints

Width thresholds in logical pixels. Use the named constant; do not add a new literal near an existing one.

| Width | Constant (file) | Effect |
|---|---|---|
| 180 | `_compactBelow` (`app/shell/sidebar/sidebar.dart`) | Sidebar uses the icon-only rail layout below this width. |
| 560 | `_historyButtonsMinWidth` (`app/shell/top_bar.dart`) | Back and forward buttons hidden below this width. Mouse side buttons still navigate. |
| 560 | `_compactBelow` (`features/settings/setting_row.dart`) | Settings rows stack their control under the label. |
| 640 | `pageHeaderCompactWidth` (`shared/widgets/page_scaffold.dart`) | Page header compacts its actions. |
| 640 | `_centerMaxWidth` (`features/player/player_bar.dart`) | Widest the player bar's controls and seek column gets. |
| 720 | `_sidebarBreakpoint` (`app/shell/app_shell.dart`) | At or above: sidebar is a column. Below: sidebar is a drawer. |
| 720 | `_compactBreakpoint` (`features/player/player_bar.dart`) | Below: compact player bar with a seek strip on its top edge. |
| 720 | `_wideBreakpoint` (`features/player/now_playing/now_playing_screen.dart`) | At or above: Now Playing shows header, body and footer. Below: one column with tabs. |
| 720 | `maxWidth` (`features/settings/settings_screen.dart`) | Settings content column is at most 720 px wide. |
| 480 × 720 | window minimum (`linux/runner/my_application.cc`, `desktop_window.dart`) | Smallest window. Default is 1280 × 720. |

## Shell layout

| Width | Sidebar | Top bar | Player bar |
|---|---|---|---|
| >= 720 px | Column: 240 px, or 72 px icon rail after collapse | 64 px; back, forward, search, Settings | 96 px, full width under the page |
| < 720 px | Drawer, opened from the top bar | 64 px; back, search, Settings | 96 px, compact layout with a seek strip |

The banner `PlaybackUnavailableBanner` sits under the top bar when the audio engine is off (library-only mode). The page fills the rest.

- **Sidebar.** Groups: Home | Songs, Albums, Artists, Genres, Languages, Folders | Queue history, Favorites, History | Playlists. The library group (Songs to Folders) is hideable: Settings → Interface has one chip per tab (at least one stays on), and it applies to the column, the rail and the drawer; on the page of a tab just hidden the user stays and no row is lit. Home and the third group are always shown. Languages (`/languages`) sits right after Genres. There is no "Current queue" row: the queue sheet opens from the queue button of the player bar. Queue history (`/queue-history`) lists the queues the user replaced, newest first: collage, when it was saved (date and time in the user's language), song count, a Play button and a menu (Play, Shuffle, Play next, Add to queue, Save as playlist, Delete with confirmation; also on right click, long press and the menu key). A row opens the saved queue at `/queue-history/:id` with the playlist entries view (play from a song, queue menu, export, drag and remove). The Playlists section lists the playlists newest first, with a "+" that asks for a name, creates the playlist and opens it. Its title and the rail entry open `/playlists` through the shell's branch switch like any destination (back to the last playlist page, or the grid when already there) and are highlighted on the grid and on every playlist page; the playlist on screen is highlighted too. In rail mode the section is a "+" and one Playlists icon, no per-playlist icons. Collapses between 240 px and 72 px in 400 ms. A tooltip names each icon in rail mode.
- **Top bar.** 64 px. Back and forward (forward and back hidden below 560 px), search field, Settings on the right at every width. Empty space drags the window.
- **Live search.** Typing opens `/search?q=…` 150 ms after the last keystroke; Enter opens it at once. Consecutive searches replace one history entry, so Back returns to the page before the search. Leaving the search page clears the field; Back or Forward onto a search restores its text from the URL.
- **Search history.** While the field has focus and is empty, the last searches (up to 20) list in a panel under it, at least 280 px wide, eight rows before it scrolls. A row has a history icon, the query and a remove button; "Clear all" ends the panel. Choosing a row (click, or Up/Down and Enter) fills the field, opens the search and moves the query to the top. Typing, Esc, losing focus or removing the last row closes the panel; the buttons never take focus from the field. A query is saved on Enter, on choosing a suggestion and on opening a result on the search page, not on each keystroke.
- **Custom title bar.** Window buttons appear only when the title bar setting is `kanaru`. Settings says the change needs a restart.
- **Reselecting a sidebar item** returns that branch to its root.
- **History.** Browser-style back and forward with a 100-entry cap. Mouse back and forward buttons work at any width.

## Player bar

- Height 96 px. Shows artwork, title and artist, transport (previous, play or pause, next), seek bar, volume, shuffle, repeat, and the queue button.
- Below 720 px: compact layout with a thin seek strip on the top edge. Controls stay in the bar.
- Shown when a queue exists (`playerBarVisibleProvider`).
- Seek bar: a straight track like the volume slider: played part in primary, a gap, an upright pill thumb, a gap, the rest in secondaryContainer. It does not animate while playing; it follows playback in pixel-sized steps (250/500/1000 ms).
- Volume: hover popup that hides itself. Scroll wheel changes volume (PLAY-04).
- Sleep timer (PLAY-14): moon button left of volume. Outlined while off; filled in primary with a short label (`m:ss`, `h:mm:ss`, or Track/Album/Queue) while on, dimmed while counting is held. The label shows only from a 1280 px window; the tooltip always has the full text. The button is left out below about 900 px (the controls column keeps its width); the compact layout shows the icon only, with no label. When the moon appears, the controls column steps down by 96 px (48 px per side) to make room. The menu (`MenuAnchor`) lists presets, Custom… and the end-of modes; while on it adds a header, +/- 5 minutes, pause or resume counting, and cancel.
- Icon buttons carry tooltips.

## Now Playing overlay

Opened from the player bar. It is an overlay, not a route: `nowPlayingOpenProvider` flags it, and the shell is excluded from focus, semantics, pointer and ticker while it is open.

| Behavior | Rule |
|---|---|
| Enter | Slides up in 500 ms. The cover animates on open (`now_playing_open_cover.dart`). No shared-element hero from the player bar yet (NP-03). |
| Exit | Esc (mapped to `DismissIntent`). Focus returns to the control that opened it. |
| Auto-hide | Header and footer fade out after 3 s of inactivity; pointer movement brings them back. |
| Wide (>= 720 px) | Header (title bar), body (cover, track info), 80 px footer split into three groups. |
| Narrow (< 720 px) | One column with tabs in a `PageView`: queue, track, and lyrics on the right when the track has them. |
| Add to playlist | The footer button opens the playlist picker for the current song. Only a song that is a library row can go in a playlist; any other says so in a snackbar. |
| Sleep timer | The moon button sits in the right group before volume, with the same menu and label rules (label from a 200 px right group). |
| Lyrics | Only when the playing track has lyrics: the right half of a wide window (the header's "Lyrics only" button gives them the whole body) or the right page of a narrow one; without lyrics the layout is unchanged. Lines are centered, headline small; the current synced line is bold in `onSurface`, the others `onSurfaceVariant` at 55%. The current line sits 40% down and auto-scroll follows it (200 ms, the same as the line's own style change; a jump under reduced motion), pausing 3 s after a manual scroll; pressing a line seeks there. Plain lyrics are static. |
| Queue tab | The queue tab (narrow window) is the same queue panel, so it also has the filter button in its header. |
| Favorite | The favorite button (heart) likes and unlikes the current song; it pops (shrinks, overshoots, settles) on each press, like the heart of song rows. |

## Queue sheet

- A panel on the right, at most 400 px wide. Not a route; Esc or the mouse back button closes it while it is open. Focus returns on close.
- Rows are 64 px. Drag handle reorders; a remove control per row; clear-all in the header.
- The current row uses the primary color (`queue_tile.dart`).
- A search button in the header opens a filter box under it (`Ctrl+F` reaches it while the sheet is open, Esc closes the box first). Matches are the real rows, best match first, without drag handle or remove button; tapping one jumps to it and leaves the queue as it is. Closing the sheet drops the filter.
- Opens and closes in 400 ms.

## Library screens

Pages opened from the sidebar (Songs, Artists, Genres, Folders, Languages) open as a grid by default; a switch to the list is remembered for the session only.

The Languages tab lists the languages named by the language tag as round tiles (name and song count), sorted by code; a language page has Play, Shuffle, its albums and its songs like a genre page, and the tab's empty state says the tags come from `TLAN` or `LANGUAGE` and that a rescan reads them.

| Screen | Layout |
|---|---|
| Songs | Virtualized list, one row per track, read in pages of 200; or a grid of covers (title and artist under each, the default), read the same way. The header button switches them per session (not kept across restarts) and a switch starts at the top. Tap plays the list from that song in the displayed order; right click opens the song menu in both. A list row (`SongTile`, also on search, Home lists, folder, artist, genre and language pages) is 80 px: a 64 px cover, then the title (semi-bold), the artist and "album • year", then the duration above a heart that likes or unlikes the song. |
| Albums | Grid of covers or list, switched and remembered (`albumsView` setting). A list row (`AlbumListTile`, also in search) is 80 px like a song row: a 64 px cover, then the title (semi-bold), "artist • year" and "N songs • M min"; while it is hovered or focused a play button shows at its end and plays the whole album from the first track. Album page lists tracks grouped by disc, each with its track number, or its cover when Settings → Interface → Track numbers in albums is off. An album merged from several artists (Album artist grouping off; judged by the album artist, or by the first track artist when the album has no album-artist tag) shows "Various artists" on its tiles and page header, without an artist link. |
| Artists | Round avatars in a grid (default) or a list, switched per session (not kept across restarts); a list row (`ArtistTile`, also in search) is 80 px like a song row: a 64 px avatar, then the name (semi-bold), "N albums • M songs" and "first year – last year • total length" ("H h M min" from an hour up), with a play button on hover or focus that plays every song of the artist (in the artist page's order on the Artists tab, album by album in search); artist page has Play, Shuffle and queue buttons, then sections for albums, songs and appears-on. |
| Genres | Round tiles in a grid (default) or a list, switched per session. Genre page has Play, Shuffle and queue buttons, then its albums and songs. |
| Folders | Tree on (default): the music folders, each opening its subfolders. Tree off: every folder that holds songs, with its path below the music folder. Grid (default) or list, switched per session. Folder page has Play, Shuffle and a menu of folder actions in the header; recursive song and folder counts sit under the name. An eye button (tree view only, per session) shows hidden items: dot-named subfolders and audio files of the viewed folder appear dimmed with a "Hidden" label, and a hidden folder opens a page read from the disk without counts. |
| Onboarding | Full-page first-run picker, outside the shell, shown once after install (adding a folder or "Later" ends it for good). Suggests the XDG music folder. |

Album, artist and genre pages have a filter button (`Ctrl+F` opens it, Esc closes and clears it): on the album page in a right-aligned row under the header, on artist and genre pages at the end of the "Songs" heading. While it filters, the album page drops the disc groups and shows the matches as one list, and the artist and genre pages hide the album sections; Play and Shuffle in the header still take every song, tapping a match plays the filtered list from it. Leaving the page drops the filter.

Sort controls sit in the page header. Sort choices are stored per screen (`librarySort` in `settings.json`). Sort keys: songs by title, artist, album, year, date added, duration; albums by title, artist, year, date added; artists by name, song count, album count.

Rescan is a button with a progress ring. The ring spins until the first batch finishes so it is visible on small libraries. It sits in the top bar, left of Settings, and stays at every window width (no floating button on the pages).

## Playlist screens

| Screen | Layout |
|---|---|
| Playlists (`/playlists`) | Grid of playlist cards, newest first, with a "New playlist" button; an empty state explains how to start. A card shows the cover collage, the name (up to two lines) and the song count. |
| Playlist page (`/playlists/<id>`) | Header with the collage (up to four distinct covers of the first songs: none gives a placeholder, one shows that cover, two show vertical halves, three a left half plus two right quarters, four a 2×2), name, count, Play, the queue menu button and an actions menu (Rename, Delete). Below it 64 px rows with a drag handle, the song, its duration and a remove button. Tap plays the available songs from that row. |
| Not in library | A row whose file is not in the library shows its file name and "Not in library", is dimmed, can be moved and removed, and is skipped on play. |
| Delete | Asks first and says how many songs go; the songs stay in the library. Leaves the page before deleting. |

**Filter.** Between the header and the rows, a search button (and `Ctrl+F`) opens a filter box; the same page serves Favorites and a saved queue. With words typed, the rows are replaced by the songs of the playlist whose title, artist or album has every word as a word prefix, best match first (title starts with it, title has it, artist or album has it; ties keep playlist order). They are read from the database, since the page only holds a window of the playlist, at most 1000; past that a line says "Showing the first 1000 songs. Type more to narrow it down.". While filtering there is no drag handle and no remove button (a position in the filtered list is not a position in the playlist); the row menu still works. A tap plays the filtered songs (not the whole playlist) from that row; Play in the header still plays everything. An entry whose file is not in the library has no song to match and does not show. Esc or the clear button brings the full list back (scroll position may reset). A filter started during a drag or removal reads after that write ended; a change to the playlist while filtering reads the matches again. An empty playlist has no filter button, and `Ctrl+F` there goes to the library-wide search; if the last entry goes away while the box is open, the box closes.

Dragging a row lifts the card itself (shadow, no wider slab); the order changes at once and is saved when the row drops. A failed save puts the rows back and says so in a snackbar. Reordering is by pointer only for now.

**Add to playlist.** Every queue menu (song rows, album and artist tiles, album and artist page headers, search songs, playlist page header and rows) has a third item, "Add to playlist…". It opens a picker over the page: "New playlist…" first, then the playlists newest first with their song counts. Duplicates are skipped silently, with no dialog: repeats inside the batch collapse to one, songs already in the playlist are dropped, the rest are appended in order. The snackbar says "Added to <playlist>: <name>", or "Added N songs to <playlist>, M were already there", or "Already in <playlist>: <name>" when nothing was new (nothing is written). A new playlist from the picker is created with the songs in one step. Duplicates already stored in a playlist are left alone.

## History page

| Screen | Layout |
|---|---|
| History (`/history`) | Every play of one year, newest first, in 64 px lines grouped by day. A day header says "Today", "Yesterday" or the full date, and how many listens; the header of the day at the top stays pinned while its rows scroll under it. Year chips (hidden with one year) pick the year; the last line offers the next older year. A calendar button opens a month grid of the selected year, with a dot under each day that has plays and the other days disabled; picking a day scrolls to its header. |
| Row | Cover, title, "artist · album", a `#N` badge (the Nth listen of that song, with a tooltip), the start time (12 or 24 hour as the system says) and a more button. A tap plays that day's songs, each once, starting at the tapped one. Right click, long press and the more button open the menu: Play next, Add to queue, Add to playlist…, Remove from history. |
| Not in library | A play whose file is gone shows its file name and "Not in library", is dimmed, does not play, and has its queue items disabled; it can still be removed. |
| Remove | No confirmation. A snackbar "Removed one listen from history" with Undo stays 4 s; Undo restores only the latest removal; one snackbar serves every History page. There is no one-tap delete on the row. |
| States | "History is not available" (no library), the empty page (with a line when recording is turned off in Settings), a spinner while the first read runs, and a failure message. |
| Tabs | "Journal" and "Most played" under the title, side by side in an `IndexedStack` (no swiping), each keeping its state. The calendar button shows on the Journal tab only. |
| Most played | A chip per range (Today, 7 days, 30 days, 6 months, 1 year, All time, Custom), then Previous period, the range label and Next period (hidden for All time; Next is off on the current period). "Play all" and "Create playlist" sit above the list and are off when no song can play. Rows are 64 px: rank, cover, title, "artist · album", listens and a more button; a tap queues the playable songs by rank from that row. The menu is the Journal one without Remove. A song not in the library is dimmed and skipped. At 500 rows a note says "Showing first 500"; a thin bar runs over the old list while a new one is read; an empty range says "No listens in this range". |
| Song history | Row menus of Journal and Most played end the queue rows with "Song history", which opens `/history/track?path=…` (the top bar's back returns to the same tab and range). Title is the song (or its file name, with "Not in library"), then "artist · album". The header has the cover, "N listens · First <date> · Last <date time>" and a Play button, shown only for a song in the library (it queues that song alone). Below, one 56 px row per play, newest first: date and time, "listened m:ss" (hidden when unknown), a `#N` badge and a more button; the menu has the queue rows and Remove from history (no Song history item), with the same Undo snackbar. No plays left shows "No listens yet"; a missing or empty path shows "Song not found". |

## Home page

The greeting is the page title. With songs in the library the body is five sections, always in this order, one scrolling column. Without songs (or without a library) it is the empty state; while the first read runs the body is blank, with no spinner.

| Part | Behavior |
|---|---|
| Section header | Title (`titleLarge`, a heading for screen readers) and a chevron button "See all" right beside it, margin 32 like the page title. The button opens the section's full list (see the next two rows). |
| See all | Recently played opens History. Recently added opens `/home/recently-added?window=<1d\|3d\|7d\|30d\|all>` on the chip in effect (without `window` while that default is still being read). Lost memories, Recent albums and Recent artists open `/home/memories`, `/home/recent-albums` and `/home/recent-artists`. The button stays enabled when a section is empty. It uses `go`, so Back in the top bar returns to Home. |
| Full lists | Page title is the section title. Songs: one `SongTile` row each (tap plays the loaded songs from the tapped one; the menu queues only that song). Albums and artists: a grid of the shelf cards, each card 168 px wide with 24 px side padding; the columns are as many as fit, so each cell is at least 168 px wide (not the 200 px maximum of the library grids). Rows are read 200 at a time and the next 200 when the end is within one screen; there is no cap. When the data changes the loaded rows are read again in one query and swapped in, so the scroll position stays. Recently added shows the same chips under the title; a `?window=` that is unknown or missing opens on the window in effect; a chip tap remembers the pick for Home and replaces the location, so the list restarts at the top. Empty: one `EmptyState` sentence ("No songs were added in this period", the memories sentence, "No albums played yet", "No artists played yet"); a failed read shows "Could not load the list" with a Retry text button (under the rows when some are loaded). These pages are screens of their own, so they keep an empty state; the rule of no placeholder text applies to the Home sections. |
| Recently played | Songs by their latest listen. Card: square cover, title, artist. A tap queues the songs of the row (at most 20) and starts at the tapped one. Right click, long press and the menu key open the song menu. |
| Recently added | Songs added inside the chip in effect, newest first, same card. Chips under the title: 1 day, 3 days, 7 days, 30 days, All. Until the user picks one, the smallest window that holds the newest song is on; a pick lasts for the session and survives leaving the page. |
| Lost memories | Songs played within three days of today's date last year, most played first, same card. With none, the one sentence "No music from this time last year" in `onSurfaceVariant`, shown only after a read finished with no rows (never while reading or after a failure with nothing to show). |
| Recent albums | Albums by their latest listen. Card: artwork, title, "artist · year" (an album merged from several artists says "Various artists"). A tap opens the album (Albums branch); the menu is the queue menu (Play next, Add to queue, Add to playlist…). |
| Recent artists | Artists by their latest listen. Card: round avatar, name, song count. A tap opens the artist; the menu is the queue menu. |
| Empty row | An empty row draws nothing: no shelf, no text, only an 8 px gap under the header (Lost memories is the one exception above). A row still being read for the first time shows placeholder squares so the page keeps its height; a later read keeps the old cards until the new ones arrive. |
| Shelf | A horizontal row of cards, each 168 px wide and as tall as cover plus two text lines at the current text scale. Round tonal arrow buttons sit on the edges, only on a side that has more cards, and scroll 80 % of the width (300 ms, an instant jump with reduced motion). The mouse drags the row; a trackpad or Shift + wheel scrolls it sideways; the plain wheel scrolls the page; Tab moves through the cards and brings the focused one into view. |

## Search page

Opens from the top bar at `/search?q=…`. An empty query shows "Search your library".

- **Sections** in order: Songs, Albums, Artists. A section without matches is hidden. Its header shows the count of all matches.
- **Rows.** Eight per section. A longer section has one toggle below its rows: "Show all (N)", or "Show top N" for songs when more than the 200 loaded songs match. "Show less" closes it in place.
- **Songs hint.** Once the songs are expanded and more match than are shown, a line says how many are shown and asks for more words.
- **Song tap** plays only that song (a queue of one). Right-click or long-press opens the queue menu (Play next, Add to queue, Add to playlist…).
- **Album and artist rows** open their pages. They have no queue menu.
- **States**, checked in this order: library unavailable; no folders; "Updating library" while keys are recomputed; loading; "Search failed" (previous results stay only while a newer query loads); no results. While the first scan runs and there are no results yet, the page shows loading instead of "No results".
- Results follow rescans while the page is open.
- **Syntax.** The query accepts `artist:`, `album:`, `genre:` (words in that field), `year:2010`, `year:>2010`, `year:<2000`, `year:2010-2015`, `format:flac` and `language:vi` (matches by language key, so `vi`, `vie` and `Vietnamese` are the same; several are alternatives; untagged songs never match); a value with spaces goes in double quotes. Unknown prefixes and broken values count as plain words. The filters and the field prefixes apply to the Songs section only. Albums and Artists use only the plain words. A query with only filters (`year:2010`) lists songs and no other section.
- **Field picker.** A "Search fields" button sits in the page header, also when the query is empty. It opens a menu with two presets ("All fields", "Titles only"), a divider and one checkbox per field: title, artist, album, album artist, genre, file name, description. The menu stays open while fields are toggled. The last field cannot be turned off. A dot and the label "Search fields (filtered)" show that the choice differs from "All fields"; on a narrow header the button is an icon with a tooltip. The choice is saved with the search history and kept across restarts. Lyrics are not offered.
- **Sections follow the fields.** Albums need plain words and the album or album artist field; Artists need plain words and the artist field. Until the saved choice has loaded the page uses "All fields". When nothing matches and the fields are not "All fields", the message also suggests turning on more fields.
- **Corrected query.** When part of the results come from a typo-fixed query (fewer than 5 songs matched as typed), a muted line “Results for “…”” sits above the first section. It shows the query with the fixed words replaced; syntax is kept. Without such results no line shows, and a query with no results at all keeps the plain “No results” state.
- **History.** The query as typed (syntax included) is saved when the user opens a result from this page: plays or queues a song, opens an album or an artist. Typing alone saves nothing.

## Cover art

- Decode sizes are bucketed to 64, 128, 256 and 512 px (`shared/widgets/cover_art.dart`). Images are never decoded at full size in lists.
- `gaplessPlayback` is on for covers so they do not flash between tracks.
- Missing artwork shows a placeholder: a solid color chosen from a stable FNV hash of the album or artist name (`shared/stable_hash.dart`, `shared/widgets/placeholder_colors.dart`). The same name always gets the same color.
- Artist avatars use the same placeholder approach.

## States

| State | Component | Rule |
|---|---|---|
| Library unavailable | Library browse body | Message that the library could not open; playback still works. |
| No roots | Library browse body | Empty state with the action to add a folder. |
| Keys updating | `library_keys_updating.dart` | "Updating library" with progress after a sort-rule change. Playback is not affected. |
| Loading | `library_loading.dart`, `MinBusyBuilder` | `MinBusyBuilder` keeps the busy state on for a minimum time, so a short task does not flash its indicator. |
| Empty | `EmptyState` (`shared/widgets/empty_state.dart`) | Icon, one sentence, optional action. |
| Scan finished | Snack bar | Result summary with counts; not a dialog. |
| Playback unavailable | `PlaybackUnavailableBanner` | Library-only mode. Pressing play reports one error and stays paused. |
| Track failed | Player error stream | Playback skips to the next track; a queue where every track fails stops (PLAY-13). |

Home uses `EmptyState` ("Your library is empty") only when the library has no song or cannot be opened. Favorites uses `EmptyState` only before the first like or when its playlist is empty.

## Settings

- Single column, at most 720 px wide, grouped in five sections, in this order: Appearance (theme, language, title bar, display options such as colors from the cover), Library (music folders, excluded folders, scan options and filters, folder watching, rescan at start, rescan), Backup and restore (placeholder), Advanced (playback with ReplayGain and the output device, interface, listen history, log folder), About (repository, license). Options that are stored but not built yet carry a coming-soon badge.
- Every row has a hint line under its title that says what the option does; keep it to one sentence. A row that needs a restart replaces its hint with "Applies after restart" until the value is changed back.
- Rows: label on the left, control on the right. Below 560 px the control moves below the label.
- Library folder rows have only a trash button, faded in while the pointer is over the row or focus is inside it (it stays in the tree, so Tab reaches it and the row does not reflow). A missing folder keeps a red button visible.
- Options that are not wired yet are shown as "Coming soon" rows (`SettingRow.comingSoon` or `SettingsChipsRow`): disabled colors, a badge after the title, the saved value shown, and no tap or focus reaches the control. Real rows come first in each section; the coming soon rows follow. Whoever wires an option removes `comingSoon` and passes a callback. Numeric options are dropdowns of preset values (`settings_number_presets.dart`); a stored value outside the presets is added to the list.
- Choices use `setting_choice.dart`: a segmented button when there is room, a dropdown in a compact row.
- Language choices: system, English, Vietnamese. The title bar choice (kanaru, system, none) needs a restart; the screen says so.
- A save warning (`settings_save_warning.dart`) appears when settings cannot be saved.

## Motion and reduced motion

| Motion | Duration | Reduced motion |
|---|---|---|
| Page transition | 300 ms (reverse 220 ms) | Fade only (`app/page_transition.dart`) |
| Branch transition | 300 ms | Fade only (`app/shell/branch_transition_container.dart`) |
| Sidebar collapse | 400 ms | Not gated in the code found by grep. Known gap; see below. |
| Queue sheet | 400 ms | Checked (`queue_sheet_host.dart`) |
| Now Playing slide | 500 ms | Checked (`now_playing_overlay.dart`) |
| Auto-hide fade | 100 to 150 ms | Not gated |
| Now Playing cover gradient fade | 300 ms | Instant (`now_playing_cover_gradient.dart`) |

Reduced motion comes from the platform setting, or from Settings → Appearance → Animations turned off: the app's builder (`lib/app/app.dart`) then sets `MediaQuery.disableAnimations` for every page, dialog and menu, and the Now Playing gradient fade is instant too. The theme change itself (`themeAnimationDuration`) is always instant. Turned on, the platform setting decides. Every new animation must check `MediaQuery.disableAnimationsOf`, never the setting itself. The sidebar collapse does not appear to check it yet; treat that as a bug to fix, not a pattern to copy.

**Text size.** Settings → Appearance → Text size (80 % to 150 %) multiplies the system's text scale in the same builder (`appTextScaler`). Enlarging stops at 2× (or at the system's scale when that is larger, so a large accessibility size is never undone). Layouts size rows and grid tiles from `MediaQuery.textScalerOf`, never from fixed heights.

## Focus, keyboard and accessibility

| Key | Action | Where |
|---|---|---|
| Space | Play or pause | App-wide, even when a button has focus; not in text fields or when there is nothing to control |
| Left, Right | Seek minus or plus 5 s | App-wide, same exceptions |
| Ctrl+S | Toggle shuffle | App-wide |
| Ctrl+R | Cycle repeat | App-wide |
| Esc | Close overlay, sheet or drawer | Now Playing, queue sheet, drawer |
| Ctrl+F | Focus the top bar search field and select its text | App-wide; a page filter box takes it first, and pressing it again inside that box goes to the top bar; nothing while a dialog, menu or Now Playing is open |
| / | Same as Ctrl+F, never opens a page filter | Only when no text input has focus; nothing while a dialog, menu or Now Playing is open |
| Mouse back, forward | History back, forward | Anywhere |

- Keys are handled by `features/player/player_shortcuts.dart`; Ctrl+F and `/` by `app/shell/top_bar_search_shortcuts.dart`, a hardware keyboard handler that returns true only when it acts, so the other keys above still work.
- Not implemented yet (SYS-03): Ctrl+Left and Ctrl+Right for track change, Up and Down for volume. Scroll over the volume button already changes volume.
- Sliders expose slider semantics.
- Focus is restored after an overlay or sheet closes.
- Contrast: use theme `on*` color pairs. Do not place text on artwork without a scrim (guideline, not enforced by a test).
- Screen reader coverage is partial (UI-11).
- Every row with a right-click menu opens the same menu from the keyboard (Menu key or Shift+F10 while focus is in the row), anchored on the row; Esc closes it and focus returns to the row (`shared/widgets/menu_keyboard_region.dart`). Queue rows have a menu too: the heart (add a library song to Favorites, or take any song out) and remove.

## Localization

- Template language is English (`app_en.arb`); Vietnamese is `app_vi.arb`.
- Every visible string comes from `context.l10n`. Do not concatenate translated fragments; use placeholders in the ARB.
- Layout must hold with longer Vietnamese strings: no fixed-width labels for text.

## Checklist for a new screen

- [ ] Uses `material_ui` and theme tokens; no new hard-coded colors.
- [ ] Layout checked at 480 px, 720 px and 1280 px wide.
- [ ] Has an empty or loading state with a sentence in `app_en.arb` and `app_vi.arb`.
- [ ] Keyboard path to every action; focus restored after overlays.
- [ ] Animations check reduced motion.
- [ ] Covers decoded at a bucket size, not full size.
- [ ] Route or breakpoint constants live at file level, with a `///` comment.
