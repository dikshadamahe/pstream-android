# PStream Android

Flutter Android client for a self-hosted PStream-style streaming aggregator.

This repo contains:

- the Android Flutter app
- a minimal Node backend wrapper around `@p-stream/providers`

It does not host media or act as a CDN. The app pulls metadata from TMDB and resolves third-party streams through a self-hosted backend stack.

## Stack

- Flutter 3.x
- Dart
- Riverpod
- go_router
- Hive
- media_kit
- Node.js 20
- Express
- `@p-stream/providers`

Note:
- the package import name remains `@p-stream/providers`
- the Git dependency source should use `xp-technologies-dev/providers`
- some upstream docs still reference `p-stream/*`, but those code references may be stale

## Project Layout

```text
backend/providers-api/   Node service for /health, /scrape, /scrape/stream
android/                 Flutter Android host app
lib/                     Flutter application code
test/                    Flutter tests
```

## Backend Architecture

```text
Flutter app -> providers-api :3001 -> simple-proxy :3000 -> streaming CDNs
                 \-> TMDB API
```

`providers-api` is in this repo under `backend/providers-api`.

`simple-proxy` is expected to run separately on the VM and is based on:
`https://github.com/xp-technologies-dev/simple-proxy`

The providers dependency is installed from:
`https://github.com/xp-technologies-dev/providers`

## Local Backend Setup

From `backend/providers-api`:

```bash
pnpm install
pnpm start
```

This backend includes a local `pnpm-workspace.yaml` that explicitly allows build scripts for `@p-stream/providers`, which is required because the dependency is installed from GitHub and needs its prepare/build step during `pnpm install`.

Default port is `3001`.

Health check:

```bash
curl http://127.0.0.1:3001/health
```

Example scrape request:

```bash
curl "http://127.0.0.1:3001/scrape?type=movie&tmdbId=550&title=Fight%20Club&year=1999"
```

## Flutter Setup

The app expects runtime defines for:

- `ORACLE_URL`
- `TMDB_TOKEN`

Example build command:

```bash
flutter build apk --release \
  --dart-define=ORACLE_URL=http://YOUR_VM_IP:3001 \
  --dart-define=TMDB_TOKEN=YOUR_TMDB_READ_TOKEN
```

## Status

The repo is in MVP build-out stage. The backend scaffold and Android project skeleton are present, but the main product flow is still under implementation.
