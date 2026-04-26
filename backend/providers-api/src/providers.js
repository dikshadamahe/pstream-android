import {
  makeProviders,
  makeStandardFetcher,
  makeSimpleProxyFetcher,
  targets,
} from "@p-stream/providers";

import { config } from "./config.js";

/**
 * Many sourcerers in `@p-stream/providers` only succeed when a
 * `proxiedFetcher` (CORS / header forwarding) is configured. Earlier builds
 * passed only `fetcher`, which silently broke most sources. We now wire a
 * `simple-proxy` fetcher when `SIMPLE_PROXY_URL` is set, falling back to
 * the standard fetcher otherwise.
 */
function buildProviders() {
  const baseFetcher = makeStandardFetcher(fetch);

  if (config.simpleProxyUrl) {
    return makeProviders({
      fetcher: baseFetcher,
      proxiedFetcher: makeSimpleProxyFetcher(config.simpleProxyUrl, fetch),
      target: targets.NATIVE,
    });
  }

  return makeProviders({
    fetcher: baseFetcher,
    target: targets.NATIVE,
  });
}

export const providers = buildProviders();
