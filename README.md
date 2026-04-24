# Veil

![Veil logo](logo.png)

Minimal Android streaming client with a self-hosted resolver stack.

Veil pulls metadata from TMDB, resolves third-party streams through your own backend, and plays them in-app. It is an aggregator only. It does not host media and does not act as a CDN.

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

## Project Layout

```text
backend/providers-api/   Node service for /health, /scrape, /scrape/stream
android/                 Flutter Android host app
lib/                     Flutter application code
test/                    Flutter tests
logo.png                 Brand mark used in README and app icon assets
```

## Backend

```text
Veil app -> providers-api :3001 -> simple-proxy :3000 -> streaming CDNs
            \-> TMDB API
```

`providers-api` lives in this repo under `backend/providers-api`.

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

Default port is `3001`.

Health check:

```bash
curl http://127.0.0.1:3001/health
```

Example scrape request:

```bash
curl "http://127.0.0.1:3001/scrape?type=movie&tmdbId=550&title=Fight%20Club&year=1999"
```

## Android Build

The app expects runtime defines for:

- `ORACLE_URL`
- `TMDB_TOKEN`

Example release build:

```bash
flutter build apk --release \
  --dart-define=ORACLE_URL=http://YOUR_VM_IP:3001 \
  --dart-define=TMDB_TOKEN=YOUR_TMDB_READ_TOKEN
```

## Notes

- The package import name remains `@p-stream/providers`.
- Upstream docs may still reference older `p-stream/*` repos, but active code references should use `xp-technologies-dev/*`.
