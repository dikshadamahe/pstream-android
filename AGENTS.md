## Project
PStream Android is a Flutter-based Android streaming aggregator modeled on the `xp-technologies-dev/p-stream` web app. It lets users browse movies and TV metadata from TMDB, scrape third-party streaming sources through a lightweight Oracle VM backend, and play streams in-app with resume progress, bookmarks, and continue-watching support. The project must stay on a $0 forever budget using free tiers only, and it is aggregator-only: it does not host media, store media, or operate as a content CDN.

## Stack
| Technology | Role |
| --- | --- |
| Flutter 3.x | Android app framework |
| Dart | Application language |
| media_kit | Video playback |
| Hive | Local persistence for progress, bookmarks, history |
| Riverpod | State management |
| go_router | App routing and navigation |
| flutter_animate | UI and transition animations |

## Developers
- Diksha: repo owner, Dev 2 (UI + screens + data layer). Branch prefix: `dev2/`
- Pracheer: contributor, Dev 1 (infra + player + scraping). Branch prefix: `dev1/`
- Git identity switching: use `switch-dev.sh` script (Diksha default, Pracheer for his commits)
- SSH hosts: `github-diksha` and `github-pracheer` (defined in `~/.ssh/config`)
- Ownership is explicit: Diksha owns UI, screens, theme fidelity, TMDB data flow, and adaptive layout; Pracheer owns Oracle VM, proxy/services, scraping flow, player flow, and playback infrastructure.
- Keep responsibilities clear when planning work: avoid mixing Dev 1 and Dev 2 scopes in the same change unless the task genuinely crosses both layers.

## Architecture
```text
                    +----------------------+
                    |      Flutter App     |
                    |   Android client     |
                    +----------+-----------+
                               |
          +--------------------+--------------------+
          |                                         |
          v                                         v
+---------------------------+          +-----------------------------+
| Oracle VM :3001           |          | TMDB API                    |
| providers-api             |          | direct from app             |
| Express wrapper around    |          | no proxy needed             |
| @p-stream/providers       |          +-----------------------------+
+-------------+-------------+
              |
              v
+---------------------------+
| Oracle VM :3000           |
| simple-proxy              |
| CORS / fetch proxy        |
+-------------+-------------+
              |
              v
+---------------------------+
| Streaming CDNs            |
| headers / proxy sensitive |
+---------------------------+
```

## Source Reference
`xp-technologies-dev/p-stream` is the design reference. For every Flutter widget, read the corresponding `.tsx` file before implementing so the Flutter version matches the original behavior, layout, and visual language.

Key files:
- `themes/default.ts` -> `AppColors`
- `src/components/media/MediaCard.tsx` -> `media_card.dart`
- `src/components/utils/Lightbar.tsx` -> `lightbar.dart`
- `src/pages/parts/player/ScrapingPart.tsx` -> `scraping_screen.dart`
- `src/components/overlays/detailsModal/` -> `detail_screen.dart`

## Version Roadmap
- MVP: Core flow working. Phone only. Oracle VM live. GitHub APK release.
- V1: All animations. All devices (tablet, TV, foldable). SSL. Code review pass.
- V2: Genre browse, themes, PiP, cast pages, featured carousel.

## Device Breakpoints
- compact `<600dp`: BottomNav, 2-col grid
- medium `600-960dp`: NavigationRail, 3-col grid
- expanded `>960dp`: NavigationRail, 4-col grid, D-pad focus for TV

## File Structure
```text
lib/
|-- main.dart                    <- MediaKit.init + Hive.init + ProviderScope
|-- config/
|   |-- app_config.dart          <- reads --dart-define for ORACLE_URL, TMDB_TOKEN
|   |-- app_theme.dart           <- AppColors, AppTextStyles, AppSpacing (from themes/default.ts)
|   |-- breakpoints.dart         <- NEW: windowClass(), gridCols(), adaptive helpers
|   `-- router.dart              <- go_router with adaptive nav
|-- models/
|   |-- media_item.dart          <- fromTmdb(), hiveKey(), posterUrl()
|   |-- stream_result.dart       <- scrape API response shape
|   `-- scrape_event.dart        <- SSE event types
|-- services/
|   |-- tmdb_service.dart        <- trending, search, getDetails, getSeasonEps, getLogo
|   `-- stream_service.dart      <- SSE client + blocking fallback + 60s timeout
|-- storage/
|   `-- local_storage.dart       <- Hive CRUD: progress, bookmarks, history
|-- providers/                   <- Riverpod - one per data domain
|   |-- tmdb_provider.dart
|   |-- stream_provider.dart
|   `-- storage_provider.dart
|-- screens/
|   |-- home_screen.dart         <- adaptive: phone bottom nav / tablet rail / TV focus
|   |-- search_screen.dart
|   |-- detail_screen.dart       <- Hero transition + resume dialog + episode picker
|   |-- scraping_screen.dart     <- SSE consumer + animated source cards
|   |-- player_screen.dart       <- media_kit + adaptive controls + progress save
|   |-- history_screen.dart      <- V1
|   `-- settings_screen.dart
`-- widgets/
    |-- media_card.dart          <- adaptive size per windowClass
    |-- category_row.dart
    |-- scrape_source_card.dart  <- StatusCircle animation
    |-- episode_list_sheet.dart
    |-- player_controls.dart     <- adaptive: compact phone / expanded tablet/TV
    |-- adaptive_nav.dart        <- NEW: BottomNav (phone) / Rail (tablet/TV)
    |-- lightbar.dart            <- V1: CustomPainter + seasonal images
    `-- blur_ellipse.dart        <- V1: RadialGradient background glows
```

## MCP Tools
- `dart-mcp-server`: all Flutter code
- `github`: fetch P-Stream source files, manage repo
- `code-review-graph`: use `get_minimal_context_tool` before every review
- `StitchMCP`: widget gen from descriptions
- `figma`: optional mockups

## GitHub Workflow
- Canonical repository: `dikshadamahe/pstream-android`
- This project must stay pushed to GitHub and documented correctly at all times.
- After every meaningful change, update the relevant documentation and push the latest work; do not leave important progress only in the local workspace.
- If behavior, setup, architecture, ownership, commands, or workflow changes, update `AGENTS.md` and any other affected docs in the same round of work.
- Update `PROGRESS.md` after every work session so the current status, completed items, in-progress work, and session log stay accurate.
- Use the correct developer identity before committing and pushing.
- Keep branches aligned with ownership when possible: `dev1/*` for infra/player/scraping work, `dev2/*` for UI/screens/data-layer work.

## Code Review Checklist (run before every PR)
- const constructors everywhere
- `ListView.builder` not `children:[]`
- No hardcoded colors (use `AppColors`)
- No hardcoded sizes (use `AppSpacing` / `MediaQuery`)
- `RepaintBoundary` around animations
- Loading + error states for every async op
- Touch targets >=44dp
- `windowClass()` used for all layout decisions
- No credentials in source code

## Oracle VM
- IP: read from `.codex/.env` as `ORACLE_VM_IP` (currently not set in this repo)
- Services: `simple-proxy` (PM2, port `3000`), `providers-api` (PM2, port `3001`)
- Test: `curl http://$ORACLE_VM_IP:3001/health`

## Key Commands
```bash
flutter build apk --release \
  --dart-define=ORACLE_URL=http://$ORACLE_VM_IP:3001 \
  --dart-define=TMDB_TOKEN=$TMDB_READ_TOKEN

./switch-dev.sh diksha    # switch to repo owner identity
./switch-dev.sh pracheer  # switch to contributor identity

code-review-graph init   # run once after scaffolding
code-review-graph serve  # started automatically by MCP
```
