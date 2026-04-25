# providers-api (“pstream-backend” in deploy docs)

Express service on **port 3001** that wraps **`@p-stream/providers`** (`targets.NATIVE`). The Flutter app points **`ORACLE_URL`** here (not at `simple-proxy` :3000).

## What is *not* in this repo

There is no separate **`@pstream-backend`** package in the Android repo: Oracle runs **this folder** (or a copy of it) under PM2 as `providers-api`.

## Adding scrapers (VidSrc, 2Embed, AutoEmbed, CinePro, …)

1. **Sourcerer ids** must exist in **`xp-technologies-dev/providers`** as `makeSourcerer({ id: '…' })`. The app sends them as the `sourceOrder` query string (comma-separated).
2. **Many embed-style sources are `disabled: true` on the `production` branch** until upstream re-enables them for `NATIVE`. Passing them in `sourceOrder` does nothing useful until the library actually runs them.
3. **Names you use ≠ ids in code** (examples from upstream `production`):
   - **AutoEmbed** → id **`autoembed`**
   - **VidSrc-style API** → **`vidsrcvip`** (“VidSrc.vip”, not a generic “VidSrc” id)
   - **Multi embed host** (closest to “2embed” style flows in tree) → **`multiembed`**
   - **embed.su** → **`embedsu`**
   - **CinePro** → **no matching sourcerer** in the public tree; it needs a **new** implementation in `providers`, then a dependency bump here.

To ship new names (e.g. true **2Embed** / **CinePro**), the work is in **`xp-technologies-dev/providers`** (new or un-archived sourcerer + tests), then:

```bash
cd backend/providers-api
pnpm install   # or npm install
# bump @p-stream/providers to your branch/commit if forked
```

Redeploy on Oracle and restart PM2.

## What we need from you (Oracle / ops)

Send (redact secrets):

1. **Output of** `curl -sS "http://<VM_IP>:3001/sources" | head -c 4000` — confirms which sourcerer **ids** your VM actually exposes.
2. **`package.json` / lockfile** line for `@p-stream/providers` (GitHub ref or npm version) running on the VM.
3. **PM2** process name and **`pm2 logs`** snippet from a slow scrape (if any).
4. Whether you can point **`@p-stream/providers`** at a **fork** (branch URL) where we enable `disabled: false` for chosen sourcerers after testing.

## Environment

| Variable | Purpose |
|----------|---------|
| `PORT` | Listen port (default `3001`) |
| `REQUEST_TIMEOUT_MS` | Cap for `runAll` (default `90000`) |
| `SIMPLE_PROXY_URL` | Optional; forwarded in `/health` for operators |

## Health check

```bash
curl -sS "http://<VM_IP>:3001/health"
```
