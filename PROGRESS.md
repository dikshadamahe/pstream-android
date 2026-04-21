# Progress

## Current Status
Project bootstrap docs, git helper files, and GitHub repository are set up — app implementation not started

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
| 2026-04-21 | Diksha/Pracheer | Created `AGENTS.md` and `PROGRESS.md` to establish project brain, ownership, workflow, and MVP tracking. |
| 2026-04-21 | Diksha/Pracheer | Added `switch-dev.sh`, `.gitignore`, and `.gitattributes` for git identity switching and repo hygiene. |
| 2026-04-21 | Diksha/Pracheer | Created GitHub repo `dikshadamahe/pstream-android` and prepared local docs for initial sync. |
