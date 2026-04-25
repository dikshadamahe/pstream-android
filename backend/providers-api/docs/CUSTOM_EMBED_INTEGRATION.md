# Integrating third-party embeds (vidsrcme, 2Embed, AutoEmbed, CinePro)

Veil’s Android app only talks to **`providers-api`** (`ORACLE_URL`). That service calls **`@p-stream/providers`** `runAll({ media, sourceOrder? })`. **New sites are not configured in Flutter or in this Express file alone** — each one needs a **sourcerer** (TypeScript) in the providers library that returns the shape `normalizeRunOutput` already expects (stream and/or embeds).

Your Oracle **`/sources`** (example `140.245.199.210:3001`) already exposes real **source** ids such as `vidlink`, `fedapi`, `fedapidb`, … and **embed** ids such as `autoembed-english`. Those strings are what `sourceOrder` must use—not marketing domain names.

---

## 1. vidsrcme.su (VidSrc.me)

**Today:** there is no `vidsrcme` id in the stock `@p-stream/providers` tree you are running; anything VidSrc‑like upstream is usually a different host/id (e.g. archived `vidsrc*` paths).

**To add it**

1. Fork **[xp-technologies-dev/providers](https://github.com/xp-technologies-dev/providers)** (or get write access).
2. Add `src/providers/sources/vidsrcme.ts` (name illustrative) using `makeSourcerer`:
   - `scrapeMovie` / `scrapeShow`: build the correct watch or API URL from `ctx.media` (TMDB id, season/episode, `imdbId` when required).
   - Return either **`stream`** (direct HLS/DASH/file) and/or **`embeds: [{ embedId, url }]`** where `embedId` is a **registered embed** in the same package (or add a dedicated embed scraper if the iframe needs extraction).
3. Register the sourcerer in the package entry that lists active sources for `targets.NATIVE`.
4. Point **`backend/providers-api/package.json`** at your Git branch/commit, `pnpm install`, redeploy Oracle, `pm2 restart providers-api`.
5. Confirm with `curl …/sources` that **`id":"vidsrcme"`** (or whatever you chose) appears.

**You must send:** example HTTP responses (HTML or JSON) for one movie and one TV episode, plus any required headers or query params, so the sourcerer can be implemented without guesswork.

---

## 2. 2Embed.cc (embed URLs + JSON API)

Official patterns you shared (implementer spec):

| Mode | Pattern |
|------|---------|
| Movie by IMDb | `https://www.2embed.cc/embed/{imdbId}` |
| Movie by TMDB | `https://www.2embed.cc/embed/{tmdbNumericId}` |
| TV by IMDb | `https://www.2embed.cc/embedtv/{imdbId}&s={season}&e={episode}` |
| TV by TMDB | `https://www.2embed.cc/embedtv/{tmdbId}&s={season}&e={episode}` |
| Full season IMDb | `https://www.2embed.cc/embedtvfull/{imdbId}` |
| Full season TMDB | `https://www.2embed.cc/embedtvfull/{tmdbId}` |

JSON API (examples):

- Movie metadata: `https://api.2embed.cc/movie?imdb_id=…`
- TV metadata: `https://api.2embed.cc/tv?imdb_id=…`
- Season: `https://api.2embed.cc/season?imdb_id=…&season=…`
- Search / trending / similar: paths under `https://api.2embed.cc/…` as in their docs.

**There is no `2embed` source id** in the public providers tree until someone adds it.

**Implementation sketch in `providers`**

- New sourcerer id e.g. **`twoembed`** (avoid numeric-leading ids).
- Prefer **TMDB** when `ctx.media.tmdbId` is present (Veil always has it from TMDB); fall back to `imdbId` when embed URL requires `tt…`.
- Minimal viable path: return **`embeds: [{ embedId: '<existing-player-embed>', url: '<2embed iframe url>' }]`** if a generic embed scraper can resolve the iframe to a stream; otherwise parse their player page or JSON API inside the sourcerer and return **`stream`** with playlist/qualities.

**You must send:** one successful `curl` response body for `api.2embed.cc/movie?…` and one for TV season, plus whether playback must go through **simple-proxy** (headers/referrer).

---

## 3. AUTOEMBED (autoembed.cc / watch-v2.autoembed.app)

On **your** Oracle embed list, the id is **`autoembed-english`** (type `embed`), not necessarily a top-level **source** named `autoembed`.

Upstream `@p-stream/providers` may still ship a **source** `autoembed` that targets `tom.autoembed.cc` APIs; it can be disabled or absent depending on branch.

**Options**

- **A)** If `fedapi` / `vidlink` already resolve streams that internally use AutoEmbed players, you may not need a separate sourcerer—tune **`SCRAPE_SOURCE_ORDER`** only.
- **B)** To prioritize AutoEmbed’s own API, add or re-enable the **`autoembed`** sourcerer in your providers fork and map it to current domains (`watch-v2.autoembed.app`, etc.), then redeploy.
- **C)** If only the **embed iframe** is needed, return `embeds` with `embedId: 'autoembed-english'` and the watch URL; the embed pipeline must know how to extract the stream from that page.

**You must send:** which domain is canonical today and a sample “get stream” JSON (redact tokens).

---

## 4. CinePro (Mintlify / CinePro Core)

CinePro Core is a **different product** from `@p-stream/providers`: an **OMSS** HTTP API (see [introduction](https://cinepro.mintlify.app/introduction.md) and [OpenAPI](https://cinepro.mintlify.app/core/api-reference/introduction.md)).

Examples from the docs:

- Movie sources by TMDB id: **`GET /v1/movies/{id}`** on *your* Core base URL.
- TV episode: **`GET /v1/tv/{id}/seasons/{season}/episodes/{episode}`** (see [TV Shows](https://cinepro.mintlify.app/core/api-reference/content/get-streaming-sources-for-a-tv-episode.md) in the index).
- Responses use **proxy paths** (`/v1/proxy?data=…`), not raw CDN URLs.

**Ways to integrate with Veil**

| Approach | Pros | Cons |
|----------|------|------|
| **A. Sidecar:** Run CinePro Core on the VM (Docker). Add a small **bridge route** in `providers-api` that calls Core and maps OMSS `SourceResponse` → the JSON shape Veil already consumes. | No fork of `providers` | You maintain mapping + auth + versioning |
| **B. Sourcerer in `providers`:** HTTP client from TypeScript to Core’s `/v1/...`, map to `SourcererOutput`. | Single `runAll` pipeline | Fork + Node fetch to Core must be reliable |
| **C. Flutter → Core directly** | Skips Oracle scrape | Breaks Veil’s “one ORACLE_URL” model; duplicates proxy/CORS logic |

Recommended: **A or B** with Core on the same private network as `providers-api`.

**You must send:** base URL of your Core instance, auth header if any, and one sample `GET /v1/movies/{tmdbId}` JSON (redacted).

---

## 5. Checklist before coding

- [ ] Confirm legal/ToS for each third-party API you call from the VM.
- [ ] Decide: **fork `xp-technologies-dev/providers`** vs **bridge in `providers-api` only** (CinePro‑style).
- [ ] For each site: **curl** examples (movie + TV) saved in the issue/PR.
- [ ] After deploy: `curl http://<VM>:3001/sources` includes new **`id`** values.
- [ ] Update app build: `--dart-define=SCRAPE_SOURCE_ORDER=…` listing those ids first.

---

## 6. Quick reference: your current Oracle source ids (excerpt)

From a live `/sources` response, **sources** include (among others):  
`vidlink`, `fedapi`, `fedapidb`, `ridomovies`, `fsharetv`, `ee3`, `animekai`, `rgshows`, `vidrock`, `tugaflix`, `movies4f`, `fsonline`, …  

**Embeds** include: `autoembed-english`, `filemoon`, `streamtape`, …  

Use only ids that appear in **your** JSON when setting `SCRAPE_SOURCE_ORDER`.
