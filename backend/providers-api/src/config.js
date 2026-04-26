function trimTrailingSlash(value) {
  return value ? value.replace(/\/+$/, "") : "";
}

export const config = {
  port: Number(process.env.PORT || 3001),
  requestTimeoutMs: Number(process.env.REQUEST_TIMEOUT_MS || 90000),
  // Defaults to the colocated simple-proxy on the same VM so the
  // proxiedFetcher in `providers.js` can resolve CORS-restricted sources
  // without an explicit env var. Override with SIMPLE_PROXY_URL if the
  // proxy lives elsewhere.
  simpleProxyUrl: trimTrailingSlash(
    process.env.SIMPLE_PROXY_URL || "http://127.0.0.1:3000",
  ),
};
