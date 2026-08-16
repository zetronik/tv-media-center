# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app for Android TV (Leanback) + phone: a browsable catalog of movies/series with torrent (magnet) links. UI text is Russian; code comments are mixed Russian/English — match the surrounding language when editing.

Note: the pubspec package name is `torrent_DB` and the Android `applicationId` is `com.example.tv_client`, while the repo dir is `tv-client`. All Dart imports are relative (`../models/movie.dart`), so the package name rarely matters.

## Commands

```bash
flutter pub get
flutter analyze                 # lints: package:flutter_lints/flutter.yaml
flutter run -d <device>         # Android only in practice (android_intent_plus, Leanback)
flutter build apk --release     # signed with the debug key (see android/app/build.gradle.kts)
flutter pub run flutter_launcher_icons   # regenerates launcher icons from assets/icon.png
```

`test/` exists but is empty — there are no tests yet. `flutter test` / `flutter test test/foo_test.dart` work once tests are added.

Bump `version:` in `pubspec.yaml` when shipping — `HomeScreen` shows it in the sidebar via `package_info_plus`.

## Architecture

### Data flow: remote SQLite bundle, not an API

There is no backend API. The entire catalog ships as a zipped SQLite file on Cloudflare R2:

- `https://pub-5977a84384ea4066a1ca832afe9ad29d.r2.dev/movies.md5` — hash of the current DB
- `https://pub-5977a84384ea4066a1ca832afe9ad29d.r2.dev/movies.zip` — the DB archive

`DbService.updateDatabase()` (`lib/services/db_service.dart`) runs on every app start via `HomeScreen._performStartupUpdate()` → `MovieProvider.initDbAndLoad()`:

1. Fetch the remote MD5, compare with `SharedPreferences['movies_db_hash']`. Match + local file present → return `2` (no update) and just open the DB.
2. Otherwise stream-download the zip (reporting progress through the `onProgress(status, progress)` callback that drives the full-screen progress UI), extract the first `*.db` entry over `movies.db` in `getDatabasesPath()`, then store the new hash. Return `1`.
3. On any failure the provider falls back to `DbService.init()` (open whatever local DB exists). Return code `0` means the update failed.

The hash is only written **after** a successful extraction, so a half-finished update re-downloads next launch. Keep that ordering.

`DbService` is a singleton (`DbService.instance`) holding a static `Database?`. Any code path that replaces the DB file must close and null `_database` first.

### SQLite schema (implied by queries)

- `movies` — `id, title, original_title, overview, rating, release_date, poster_url, countries, genres, directors, actors`. `genres` is a free-text string; categories are derived from it with `LIKE` matching on Russian words, not a normalized table.
- `torrents` — `id, movie_id, topic_title, size_gb, quality, file_format, translation, magnet_link, seeds, leeches`.
- `now_playing` — `movie_id` only; drives the "Сейчас смотрят" category.

Category rules live in `DbService.getMovies()`: `movies` = NOT сериал/мультфильм/анимация, `cartoons` = мультфильм OR анимация, `series` = сериал, `favorites` = id IN local favorite ids. Adding a category means adding a branch there **and** a sidebar button in `home_screen.dart`.

Search normalizes `ё`→`е` on both sides (`REPLACE(LOWER(title), 'ё', 'е')`) and requires ≥3 chars, debounced 800 ms.

`Movie.fromMap`/`Torrent.fromMap` accept both snake_case and camelCase keys and coerce loose types — the DB is externally generated, so keep the parsing defensive.

### State

`provider` (not Riverpod/Bloc, despite the flutter-expert skill's defaults). Wired in `main.dart`:

- `FavoritesProvider` — favorite movie ids in `SharedPreferences['favorites_movies']` (list of stringified ints).
- `MovieProvider` — paged movie list (`_limit = 100`, offset paging), current category, and all filter state (`filterOnlyTorrents`, year exact/range, genre include/exclude), plus DB-update progress (`isUpdatingDb`, `updateStatus`, `updateProgress`).

They are joined by a `ChangeNotifierProxyProvider`: favorites changes call `MovieProvider.updateFavorites()`, which reloads only when the favorites tab is active. Any filter/category setter calls `_reloadCurrentCategory()` (reset list + page, reload). `loadMoreMovies()` is triggered by the `ScrollController` 200 px before the end.

Three invariants in `MovieProvider` exist to keep the TV UI from flickering — preserve them when touching load logic:

- **`_requestToken`** is bumped on every reload; `_fetchPage` drops its result if the token moved. Without it, flipping tabs quickly on a remote merges the previous category's rows into the new list.
- **`isLoading` is set to `true` before the `notifyListeners()` that clears the list**, otherwise a frame renders with an empty list and `isLoading == false` — i.e. a flash of "Нет контента." between categories.
- **`_notify()`** replaces the old blanket `Future.microtask(notifyListeners)`. It notifies synchronously unless the scheduler is in `persistentCallbacks`, in which case it defers to a post-frame callback. The microtask version let state and listeners drift apart (list already cleared, `GridView` still holding the old `itemCount`).

`movies` is replaced by a fresh list rather than mutated in place, so the grid never reads a list that changed under it.

### TV / D-pad focus, the main UI constraint

This is a remote-control-first app. Patterns used throughout:

- Layout branches on size, not platform: `width >= 600` → sidebar layout (TV/desktop) vs AppBar + Drawer (phone); `height < 600` → `isTvLayout`, a denser variant with smaller paddings/fonts.
- Focus feedback is manual: widgets are `StatefulWidget`s with a `bool _isFocused` set from `InkWell.onFocusChange`, rendering a white border via `AnimatedContainer` (`MovieCard`, `TorrentCard`, `_MenuButton`, `_FilterButton`). Ink splash/hover colors are set transparent so only the border reads on a TV. New interactive widgets should follow this instead of relying on default focus theming.
- Grid edge scrolling: `_EdgeScrollAnchor` (`home_screen.dart`, `canRequestFocus: false`) animates the scroll view to top/bottom when the first/last row gains focus, so D-pad navigation doesn't strand items under the toolbar. It runs in a post-frame callback deliberately — firing during the same frame put it in a tug-of-war with the framework's own `ensureVisible` animation on the same `ScrollController`.
- The paging indicator lives in a fixed-height `SizedBox` **below** the grid, never as an extra grid cell. As a cell it changed `itemCount`, which shifted every card and moved the "last row" boundary under an already-focused card.
- `_InfoTab` in `movie_details_screen.dart` intercepts arrow keys to scroll manually (no focusable children to move between).
- The search screen renders its own on-screen keyboard (`_buildTvKeyboard`, RU/EN/123 layouts) plus `speech_to_text` voice input, since the system IME is awkward with a remote. The search field's `FocusNode` maps OK/Enter to `SystemChannels.textInput.invokeMethod('TextInput.show')` and Down to `unfocus()`.
- `MovieDetailsScreen` uses `IndexedStack` + `AutomaticKeepAliveClientMixin` rather than `TabBarView` to avoid tab-slide flicker and refetching torrents.

Performance idioms already in place and worth keeping: `RepaintBoundary` around cards, poster images extracted into separate stateless widgets so focus repaints don't touch the image layer, `ValueKey(id)` on the outermost grid child (put the key on the wrapper, not on the `MovieCard` inside it, or focus state desyncs when the list changes).

Poster decoding is the single biggest memory lever on a TV box. `_MoviePoster` passes `memCacheWidth`/`maxWidthDiskCache` sized from the actual cell constraints × `devicePixelRatio`; the source is a 500×750 TMDB image that would otherwise cost ~1.5 MB of RAM each and blow past the `ImageCache` budget within one 100-item page, causing already-loaded posters to re-decode on scroll. `main.dart` caps the cache at 48 MB / 400 entries. Poster placeholders are static (`_PosterStub`) — a `CircularProgressIndicator` per cell means dozens of tickers repainting every frame.

### Playback

Tapping a torrent fires an `AndroidIntent(action: 'action_view', data: magnetLink)` — the magnet is handed to Ace Stream / any magnet handler. `AndroidManifest.xml` declares the required `<queries>` entries (`org.acestream.media`, `magnet:` and `market:` VIEW intents); a new external-app hand-off needs a matching `<queries>` entry or the intent silently fails on Android 11+.

Also in the manifest: Leanback launcher category + `android:banner`, `leanback`/`touchscreen` marked not required, `RECORD_AUDIO` for voice search, and `usesCleartextTraffic="true"`.

## Repo conventions

Two project skills live in `.claude/skills/`: `flutter-expert` and `ui-ux-pro-max`. `.cursorrules`, `.clinerules`, and `.windsurfrules` are identical copies of each other and still describe these skills as living in `.agents/skills/` — that path no longer exists.

The flutter-expert skill assumes Riverpod/Bloc + GoRouter; this project uses `provider` and imperative `Navigator.push` — follow the existing code, not the skill's defaults.

`ui-ux-pro-max/SKILL.md` documents a `scripts/search.py` and a `data/` database, but neither was ever present in this repo (they were dangling symlink stubs pointing at a nonexistent `src/` tree). Treat the SKILL.md as reference prose only; the search commands in it will not run.
