# PStream Android — Codex Prompt Sequence
# Run these IN ORDER. Each prompt builds on the previous.
# Model: GPT-5.4 High
# Tool: Codex CLI in project root (C:\Users\Pracheer\Documents\P-Stream)

========================================================================
PROMPT 0 — BEFORE ANYTHING ELSE (run this once, standalone)
========================================================================

Read the file `kt.html` in the current directory. Extract and internalize:
- The complete project description (Flutter Android streaming aggregator)
- The version roadmap: MVP, V1, V2 and what each contains
- The two developers: Diksha (repo owner, Dev 2 — UI) and Pracheer (contributor, Dev 1 — infra/player)
- The full Flutter project structure from Section 10
- The Oracle VM setup (AMD EPYC E2.1.Micro, always-free)
- The providers-api architecture (Node.js wrapping @p-stream/providers on port 3001)
- The simple-proxy (xp-technologies-dev/simple-proxy on port 3000)
- The AppColors system from themes/default.ts
- The all-device support breakpoints (compact/medium/expanded)
- The code review checklist

Do NOT write any code yet. Just confirm you have read and understood the KT.
Summarise back to me in 10 bullet points what this project is and how it works.

========================================================================
PROMPT 1 — CREATE AGENTS.md (context file for all future sessions)
========================================================================

You have read kt.html. Now create `AGENTS.md` in the project root.

AGENTS.md must be the complete project brain — any new Codex session reading ONLY
this file should have everything needed to continue work without reading kt.html.

Write AGENTS.md with these exact sections:

## Project
One paragraph: what PStream Android is, what it does, the $0 constraint, aggregator-only.

## Stack
Table: Flutter 3.x, Dart, media_kit, Hive, Riverpod, go_router, flutter_animate.

## Developers
- Diksha: repo owner, Dev 2 (UI + screens + data layer). Branch prefix: dev2/
- Pracheer: contributor, Dev 1 (infra + player + scraping). Branch prefix: dev1/
- Git identity switching: use switch-dev.sh script (Diksha default, Pracheer for his commits)
- SSH hosts: github-diksha and github-pracheer (defined in ~/.ssh/config)

## Architecture (one ASCII diagram)
Flutter App → Oracle VM :3001 (providers-api) → Oracle VM :3000 (simple-proxy) → Streaming CDNs
Flutter App → TMDB API directly (no proxy needed)

## Source Reference
xp-technologies-dev/p-stream is the design reference. For every Flutter widget,
read the corresponding .tsx file before implementing. Key files:
- themes/default.ts → AppColors
- src/components/media/MediaCard.tsx → media_card.dart
- src/components/utils/Lightbar.tsx → lightbar.dart
- src/pages/parts/player/ScrapingPart.tsx → scraping_screen.dart
- src/components/overlays/detailsModal/ → detail_screen.dart

## Version Roadmap
MVP: Core flow working. Phone only. Oracle VM live. GitHub APK release.
V1:  All animations. All devices (tablet, TV, foldable). SSL. Code review pass.
V2:  Genre browse, themes, PiP, cast pages, featured carousel.

## Device Breakpoints
compact <600dp: BottomNav, 2-col grid
medium 600-960dp: NavigationRail, 3-col grid
expanded >960dp: NavigationRail, 4-col grid, D-pad focus for TV

## File Structure
[Paste the exact file tree from Section 10 of kt.html]

## MCP Tools
- dart-mcp-server: all Flutter code
- github: fetch P-Stream source files, manage repo
- code-review-graph: use get_minimal_context_tool before every review
- StitchMCP: widget gen from descriptions
- figma: optional mockups

## Code Review Checklist (run before every PR)
- const constructors everywhere
- ListView.builder not children:[]
- No hardcoded colors (use AppColors)
- No hardcoded sizes (use AppSpacing / MediaQuery)
- RepaintBoundary around animations
- Loading + error states for every async op
- Touch targets ≥44dp
- windowClass() used for all layout decisions
- No credentials in source code

## Oracle VM
IP: [read from .codex/.env as ORACLE_VM_IP]
Services: simple-proxy (PM2, port 3000), providers-api (PM2, port 3001)
Test: curl http://$ORACLE_VM_IP:3001/health

## Key Commands
flutter build apk --release \
  --dart-define=ORACLE_URL=http://\$ORACLE_VM_IP:3001 \
  --dart-define=TMDB_TOKEN=\$TMDB_READ_TOKEN

code-review-graph init   # run once after scaffolding
code-review-graph serve  # started automatically by MCP

========================================================================
PROMPT 2 — CREATE PROGRESS.md
========================================================================

Create `PROGRESS.md` in the project root.

This file tracks what has been done, what is in progress, and what is next.
It will be updated after every work session. Format:

---

# Progress

## Current Status
[one line: e.g. "Project setup — not started"]

## MVP Checklist

### Dev 1 (Pracheer) — Infra + Player
- [ ] Oracle VM: Node 20, pnpm, PM2 installed
- [ ] 1GB swap added
- [ ] simple-proxy deployed and running :3000
- [ ] providers-api deployed and running :3001
- [ ] Test: /scrape returns stream URL for Fight Club (tmdbId=550)
- [ ] OCI Console + iptables ports open
- [ ] stream_service.dart (SSE + fallback)
- [ ] player_screen.dart (media_kit + headers + progress save)
- [ ] player_controls.dart (seek bar + overlay)
- [ ] scraping_screen.dart (SSE → animated cards)
- [ ] adaptive_nav.dart
- [ ] GitHub Actions APK build workflow

### Dev 2 (Diksha) — UI + Data
- [ ] flutter create + pubspec.yaml
- [ ] main.dart (MediaKit.init + Hive + ProviderScope)
- [ ] app_theme.dart (all AppColors from themes/default.ts)
- [ ] breakpoints.dart
- [ ] MediaItem model
- [ ] tmdb_service.dart
- [ ] local_storage.dart
- [ ] router.dart
- [ ] home_screen.dart
- [ ] media_card.dart
- [ ] search_screen.dart
- [ ] detail_screen.dart

### Integration
- [ ] End-to-end: Search → Detail → Play → Video plays
- [ ] Resume works
- [ ] Bookmark works
- [ ] Tested on physical Android device
- [ ] APK builds successfully
- [ ] GitHub Release v0.1.0-mvp published

## V1 Checklist
[leave blank — add when MVP ships]

## V2 Checklist
[leave blank — add when V1 ships]

## Session Log
| Date | Dev | What was done |
|------|-----|---------------|
| [date] | [Diksha/Pracheer] | [description] |

---

========================================================================
PROMPT 3 — CREATE switch-dev.sh (git identity script)
========================================================================

Create `switch-dev.sh` in the project root.

This script switches git identity before committing, based on which dev is pushing.
Read the PAT.txt file in the project root to get names, emails, and SSH host aliases.

The script should:
1. Accept one argument: "diksha" or "pracheer"
2. Set git config user.name and user.email accordingly
3. Set the remote URL using the correct SSH host alias (github-diksha or github-pracheer)
4. Print confirmation of which identity is now active

Also create `.gitattributes` that sets LF line endings for .dart files.

Also create `.gitignore` that includes:
- .codex/.env
- PAT.txt
- *.keystore
- key.properties
- .dart_tool/
- build/
- .flutter-plugins
- .flutter-plugins-dependencies

========================================================================
PROMPT 4 — SCAFFOLD FLUTTER PROJECT
========================================================================

Now scaffold the Flutter project structure. Read AGENTS.md for the exact file list.

Steps:
1. Run: flutter create . --project-name pstream_android --org com.pstream.android --platforms android
2. Delete the default lib/main.dart content (we write our own)
3. Create all directories: lib/config, lib/models, lib/services, lib/storage, lib/screens, lib/widgets, lib/providers
4. Create pubspec.yaml with ALL dependencies from AGENTS.md (media_kit, hive_flutter, flutter_riverpod, go_router, cached_network_image, flutter_animate, shimmer, google_fonts, flutter_adaptive_scaffold, http, dio)
5. Update android/app/src/main/AndroidManifest.xml:
   - Add INTERNET permission
   - Add usesCleartextTraffic="true" (MVP only, removed in V1 when SSL added)
   - Set minSdkVersion 23 in build.gradle

Do NOT create any lib/ dart files yet — just directories and pubspec.yaml.
Run: flutter pub get and confirm it succeeds.

========================================================================
PROMPT 5 — WRITE app_theme.dart (fetch source first)
========================================================================

Use the github MCP to fetch this file:
Repository: xp-technologies-dev/p-stream
Branch: production
File: themes/default.ts

Read the file carefully. Extract ALL color values from the token system:
- black scale (c50 through c250)
- shade scale (c25 through c900)
- purple scale (c50 through c900)
- blue scale
- ash scale
- semantic colors (success, error, warning)
- component tokens (video.scraping.loading, video.context.background, etc)
- lightBar.light token
- background.accentA and accentB

Then create lib/config/app_theme.dart with:
- AppColors class (all tokens as static const Color)
- AppTextStyles class (DM Sans via google_fonts)
- AppSpacing class (4px base unit matching Tailwind)
- AppTheme.dark() that returns a full Flutter ThemeData using these colors

Use ONLY values from the fetched file. Do not invent any values.

After writing, use dart-mcp-server to format the file.

========================================================================
PROMPT 6 — WRITE breakpoints.dart + adaptive_nav.dart
========================================================================

Create lib/config/breakpoints.dart:
- WindowClass enum: compact, medium, expanded
- windowClass(BuildContext) function using MediaQuery.sizeOf
- gridCols(BuildContext) returning 2/3/4 per class
- isTV(BuildContext) returning true if expanded
- No hardcoded pixel values anywhere except the breakpoint thresholds (600, 960)

Create lib/widgets/adaptive_nav.dart:
- AdaptiveNav widget wrapping child with BottomNavigationBar on compact
- NavigationRail on medium and expanded
- 4 destinations: Home, Search, My List, Settings
- Use AppColors for all colors
- TV (expanded): NavigationRail with extended=false, larger icons

Run dart-mcp-server dart_format on both files after writing.

========================================================================
PROMPT 7 — INITIALIZE CODE REVIEW GRAPH
========================================================================

The Flutter project is now scaffolded.

Run in the project root:
  code-review-graph init

This builds the initial dependency graph from the Dart files.

Then run a test review:
  Use code-review-graph get_minimal_context_tool on lib/config/app_theme.dart

Confirm the tool returns relevant context.
Report back: how many files were loaded, what was included.

After confirming it works, note in PROGRESS.md:
  "code-review-graph initialized — [date]"

========================================================================
PROMPT 8 — WRITE MediaItem model + TmdbService
========================================================================

Use github MCP to fetch:
- xp-technologies-dev/p-stream: src/backend/metadata/types/mw.ts
- xp-technologies-dev/p-stream: src/backend/metadata/tmdb.ts
- xp-technologies-dev/p-stream: src/backend/metadata/search.ts

Read all three files to understand the data shapes.

Then create lib/models/media_item.dart:
- MediaItem class matching MWMediaMeta shape
- Fields: tmdbId (int), type (String: 'movie'|'show'), title, overview, posterPath,
  backdropPath, year (int), imdbId (nullable), rating (double), seasons (List<Season>)
- fromTmdb(Map json) factory for TMDB API response
- hiveKey() method: returns 'movie-550' or 'show-1399'
- posterUrl([String size]) method: builds full TMDB image URL

Create lib/models/season.dart and lib/models/episode.dart from the same source.
Create lib/models/stream_result.dart matching the providers-api response shape.
Create lib/models/scrape_event.dart for SSE event types (init/start/update/embeds/done/error).

Then create lib/services/tmdb_service.dart:
- getTrending(String type, String window) → List<MediaItem>
- search(String query) → List<MediaItem>  (debounce handled by caller)
- getDetails(int id, String type) → MediaItem (includes external_ids, seasons)
- getSeasonEpisodes(int showId, int seasonNum) → List<Episode>
- All calls use Authorization: Bearer ${AppConfig.tmdbReadToken}
- Simple in-memory cache: Map<String, dynamic> with 60min TTL

Create lib/config/app_config.dart reading from --dart-define:
- proxyBaseUrl from ORACLE_URL
- tmdbReadToken from TMDB_TOKEN

After writing, use code-review-graph get_minimal_context_tool on tmdb_service.dart.
Then use dart-mcp-server to review and format.

========================================================================
PROMPT 9 — WRITE local_storage.dart (Hive)
========================================================================

Create lib/storage/local_storage.dart with:

Three Hive boxes: 'bookmarks', 'progress', 'watch_history'
All values stored as Map (no TypeAdapters needed for MVP — simpler).

Methods:
- saveProgress(mediaKey, positionSecs, durationSecs, MediaItem)
  → auto-adds to watch_history when pos/dur > AppConfig.watchedRatio (0.90)
- getProgress(mediaKey) → Map? (null if not found)
- getContinueWatching() → List<Map> sorted by updatedAt, filtered 0.03–0.90
- toggleBookmark(MediaItem) → bool (true = added, false = removed)
- isBookmarked(MediaItem) → bool
- getAllBookmarks() → List<Map>
- addToHistory(MediaItem)
- getHistory() → List<Map> sorted by watchedAt DESC
- clearProgress() and clearBookmarks() for settings screen

Static mediaKey helper: 'movie-550' for movies, 'show-1399' for shows.
For episodes: 'show-1399-s2e5'

All methods are static. Initialize boxes in main.dart before using.

Use code-review-graph before and after writing.
Format with dart-mcp-server.
Update PROGRESS.md: mark local_storage.dart done.

========================================================================
PROMPT 10 — WRITE home_screen.dart + media_card.dart
========================================================================

First use github MCP to fetch:
- src/components/media/MediaCard.tsx
- src/components/media/WatchedMediaCard.tsx
- src/pages/parts/home/BookmarksPart.tsx
- src/pages/parts/home/WatchingPart.tsx

Read all four files carefully. Note:
- Card aspect ratio (poster: portrait 2:3)
- Gradient overlay direction and colors
- Progress bar threshold (5%–90% from WatchedMediaCard)
- Hover effect (Flare — port as InkWell ripple on mobile)
- Skeleton state structure

Create lib/widgets/media_card.dart:
- MediaCard widget accepting MediaItem
- Adaptive size: compact=130×195dp, medium=150×225dp, expanded=180×270dp
- CachedNetworkImage for poster with shimmer placeholder
- Bottom gradient overlay (black, from 50% height)
- Title text bottom-left, 2 lines max
- Progress bar at bottom if progress 5%–90% (read from LocalStorage)
- Bookmark indicator (small purple dot top-right if bookmarked)
- HapticFeedback.lightImpact on tap
- onTap navigates to detail screen
- Wrap root widget in RepaintBoundary

Create lib/screens/home_screen.dart:
- SingleChildScrollView with Column
- Section: "Continue Watching" (only if getContinueWatching() non-empty)
- Section: "My List" (only if getAllBookmarks() non-empty)
- Section: "Trending Movies" (TmdbService.getTrending('movie','week'))
- Section: "Trending TV" (TmdbService.getTrending('tv','week'))
- Section: "Popular" (TmdbService.getTrending('movie','day'))
- Each section is a CategoryRow widget (horizontal ListView.builder)
- Shimmer loading while data loads
- Use windowClass() for grid layout decisions

Create lib/widgets/category_row.dart:
- Title text + horizontal ListView.builder of MediaCard
- Height: compact=230dp, medium=265dp, expanded=310dp

After writing, use code-review-graph get_minimal_context_tool on home_screen.dart.
Check: const constructors, ListView.builder, AppColors only, no hardcoded sizes.
Fix any issues. Update PROGRESS.md.

========================================================================
PROMPT 11 — WRITE search_screen.dart + detail_screen.dart
========================================================================

Use github MCP to fetch:
- src/pages/SearchView.tsx
- src/components/overlays/detailsModal/components/layout/DetailsModal.tsx
- src/components/overlays/detailsModal/components/layout/DetailsContent.tsx
- src/components/overlays/detailsModal/components/sections/DetailsBody.tsx

Create lib/screens/search_screen.dart:
- Auto-focus TextField on screen open
- 400ms debounce timer, fires TmdbService.search() after typing stops
- 2-column GridView.builder of MediaCard on compact, 3-col on medium+
- Empty state: show trending suggestions
- Clear button when text present
- No search history needed for MVP

Create lib/screens/detail_screen.dart:
- Receives MediaItem as route argument
- Hero widget wrapping poster image (tag: 'poster-\${media.tmdbId}')
- Full-width backdrop image behind content
- Radial gradient glow (accentA + accentB colors from AppColors)
- Title, year, rating, genres
- Overview text (3 lines, expandable tap)
- [▶ Play] button (purple) → navigates to scraping_screen
- [⊕ Bookmark] toggle button
- Resume dialog: if getProgress(hiveKey) has ratio 3%–90%, show AlertDialog
  "Continue from X:XX?" with [Resume] and [Start Over] actions
- For TV shows: Season/Episode picker → bottom sheet (see PROMPT 12)
- Cast row (from MediaItem.credits if available)

Both screens: adaptive layout using windowClass().
Code review with code-review-graph before finalizing.
Update PROGRESS.md.

========================================================================
PROMPT 12 — WRITE episode_list_sheet.dart
========================================================================

Use github MCP to fetch:
- src/components/overlays/detailsModal/components/layout/DetailsContent.tsx
  (EpisodeCarousel section, lines 81-102)

Create lib/widgets/episode_list_sheet.dart as a DraggableScrollableSheet:
- Tab bar at top for season selection (Season 1, Season 2, etc)
- Episode list below: still image thumbnail + episode number + title + overview
- Current progress shown on episode row if it exists in Hive
- Highlight currently watching episode (last progress entry)
- Tapping episode: closes sheet, updates selected season/episode, triggers scraping

========================================================================
PROMPT 13 — WRITE stream_service.dart + scraping_screen.dart
========================================================================

THIS IS DEV 1 (PRACHEER) TERRITORY.
Run: ./switch-dev.sh pracheer before committing this work.

Create lib/services/stream_service.dart:
- scrapeStream(MediaItem, {int? season, int? episode}) → Stream<ScrapeEvent>
  Connects to SSE endpoint: GET \${AppConfig.proxyBaseUrl}/scrape/stream
  Parses line-by-line, yields ScrapeEvent objects
  60s timeout: if no 'done' event in 60s, throw TimeoutException
  On SSE connection error: falls back to scrapeBlocking()
- scrapeBlocking(MediaItem, ...) → Future<StreamResult?>
  Calls GET /scrape (blocking, 90s timeout)
  Returns null if 404

Create lib/screens/scraping_screen.dart:
- Receives MediaItem + optional season/episode as route args
- Calls stream_service.scrapeStream()
- Maintains Map<String, ScrapeStatus> for each source
- ScrapeStatus enum: waiting, pending, success, failure, notfound
- ListView of ScrapeSourceCard widgets, one per source
- Auto-scrolls to currently pending source (ScrollController.animateTo)
- On 'done' event: navigate to player_screen with stream result
- On all-failure: show "No sources found" with [Try Manually] button
  Manual picker: list of all sources, tap to retry single source

Create lib/widgets/scrape_source_card.dart:
- StatusCircle: grey (waiting), animated purple ring (pending), green ✓ (success), red ✗ (fail)
- Pending animation: use flutter_animate .shimmer() or AnimationController repeat
- Source name text
- Embed sub-items when 'embeds' event received

CRITICAL: RepaintBoundary around each StatusCircle animation.
Code review with code-review-graph. Update PROGRESS.md.

========================================================================
PROMPT 14 — WRITE player_screen.dart + player_controls.dart
========================================================================

THIS IS DEV 1 (PRACHEER) TERRITORY.
Run: ./switch-dev.sh pracheer before committing this work.

Use github MCP to fetch:
- src/components/player/atoms/Volume.tsx
- src/components/player/atoms/NextEpisodeButton.tsx
- src/components/player/base/LeftSideControls.tsx
- src/components/player/atoms/SubtitleDelayPopout.tsx

Create lib/screens/player_screen.dart:
- Initialize Player() with 32MB buffer
- Open Media(url, httpHeaders: stream.headers ?? {})
  ALWAYS pass headers — never open URL bare
- If stream.proxiedPlaylist exists, use that instead of stream.playlist
- Seek to resumeFrom if provided, after first playing event
- SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky) on enter
- Restore SystemChrome on dispose
- Save progress to Hive via Timer.periodic every 10 seconds
- Landscape-only orientation for player
- ALWAYS dispose: timer.cancel(), player.dispose() in dispose()

Create lib/widgets/player_controls.dart:
- AnimatedOpacity overlay: visible on tap, auto-hide 3s timer
- Top bar: back button, media title, subtitle toggle
- Center: play/pause (large), skip -10s, skip +10s
- Bottom: custom seek bar (buffered gray + played purple), time labels
- Bottom right: source switcher button (→ opens source sheet), fullscreen icon
- NextEpisodeButton: appears when position/duration > 0.90, for TV shows only
- Glassmorphism container: BackdropFilter blur 20 + semi-transparent dark bg

Both: wrap animation widgets in RepaintBoundary.
Code review. Update PROGRESS.md.

========================================================================
PROMPT 15 — INTEGRATION + ROUTER + MAIN
========================================================================

Wire everything together.

Create lib/config/router.dart with go_router:
Routes:
- / → home_screen (with AdaptiveNav wrapper)
- /search → search_screen
- /detail/:id → detail_screen (extra: MediaItem)
- /scraping → scraping_screen (extra: MediaItem + season/episode)
- /player → player_screen (extra: StreamResult + MediaItem + resumeFrom)
- /settings → settings_screen
- /history → history_screen (V1, stub for now)

Create lib/main.dart:
- async main()
- WidgetsFlutterBinding.ensureInitialized()
- MediaKit.ensureInitialized()
- await Hive.initFlutter()
- await Future.wait([Hive.openBox('bookmarks'), Hive.openBox('progress'), Hive.openBox('watch_history')])
- runApp(ProviderScope(child: PStreamApp()))

Create lib/providers/ files (Riverpod):
- tmdb_provider.dart: trendingMoviesProvider, trendingTVProvider, searchProvider
- storage_provider.dart: continueWatchingProvider, bookmarksProvider
- stream_provider.dart: scrapeStreamProvider

Create lib/screens/settings_screen.dart (minimal):
- Show current proxy URL (from AppConfig)
- "Clear Watch History" button
- "Clear Bookmarks" button
- App version
- Link to GitHub releases page

Run: flutter analyze — fix all warnings.
Run: flutter build apk --release --dart-define=ORACLE_URL=... --dart-define=TMDB_TOKEN=...
Confirm APK builds. Update PROGRESS.md.

========================================================================
PROMPT 16 — FINAL CODE REVIEW BEFORE MVP RELEASE
========================================================================

Use code-review-graph get_minimal_context_tool on the entire lib/ directory.

Run a full code review against this checklist. Report findings:

ARCHITECTURE:
- [ ] No business logic in widget build() methods
- [ ] All HTTP calls are in services/ only
- [ ] All Hive calls are in storage/ only
- [ ] Riverpod providers are the only state access from UI

PERFORMANCE:
- [ ] const constructors on all leaf widgets
- [ ] ListView.builder / GridView.builder used everywhere
- [ ] RepaintBoundary on: scraping status circles, lightbar (if added), progress bars
- [ ] CachedNetworkImage for all network images
- [ ] No setState rebuilding parent when only child needs update

DEVICE:
- [ ] No hardcoded pixel values except in breakpoints.dart thresholds
- [ ] windowClass() used for all layout decisions
- [ ] Touch targets ≥44dp
- [ ] SafeArea used on all screens

SECURITY:
- [ ] No ORACLE_URL hardcoded
- [ ] No TMDB_TOKEN hardcoded  
- [ ] Stream.headers always passed to media_kit

For each failing check: fix it. Then re-run.
When all checks pass: Update PROGRESS.md, commit with message:
"review: full MVP code review pass — all checks green"

========================================================================
PROMPT 17 — TAG AND RELEASE MVP
========================================================================

1. Ensure switch-dev.sh is set to Diksha (repo owner) for the release tag
2. Run: git tag v0.1.0-mvp
3. Run: git push origin v0.1.0-mvp
4. GitHub Actions will build the APK automatically (see .github/workflows/release.yml)
5. Monitor the Actions tab for build success
6. Confirm the GitHub Release is created with APK attached
7. Update PROGRESS.md: mark all MVP items complete, add session log entry

========================================================================
ONGOING PROMPT — START OF EVERY NEW SESSION
========================================================================

Use this at the start of any new Codex session to restore context:

Read AGENTS.md completely.
Read PROGRESS.md completely.
Report:
1. What version are we on? (MVP / V1 / V2)
2. What is the next unchecked item in PROGRESS.md?
3. Which developer's work is next? (Diksha or Pracheer)
4. Should I run switch-dev.sh before we start?

Then: use code-review-graph get_minimal_context_tool on the files we'll be working on today.
Do not load anything else. Let's begin.

========================================================================
NOTES ON USING CODE-REVIEW-GRAPH WELL
========================================================================

The tool works best when you tell it what you're about to do:

# Good:
"Use code-review-graph to get context for implementing the scraping screen,
 which calls stream_service.dart and writes to scraping_screen.dart"

# Bad:
"Use code-review-graph"   ← too vague, loads too much

Always use it BEFORE writing a new file (understand dependencies)
and AFTER writing (review against neighbors).

It will NOT load kt.html — that file is not Dart. That's fine.
AGENTS.md is your context source for new sessions.
