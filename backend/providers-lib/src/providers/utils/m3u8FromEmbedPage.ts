import { load } from 'cheerio';

import { UseableFetcher } from '@/fetchers/types';
import { NotFoundError } from '@/utils/errors';

const M3U8_RE = /(https?:\/\/[^\s"'\\<>]+?\.m3u8[^\s"'\\<>]*)/gi;
const SCRIPTED_IFRAME_RE = /src\s*:\s*['"]([^'"]*(?:\/prorcp\/|\/rcp\/)[^'"]*)['"]/gi;
const DOMAIN_RE = /https:\/\/[a-z0-9.-]+/gi;
const MAX_DEPTH = 4;

/**
 * Best-effort: pull m3u8 URLs from raw HTML/JS.
 */
function allM3u8InText(text: string): string[] {
  M3U8_RE.lastIndex = 0;
  const values = new Set<string>();

  let match: RegExpExecArray | null = null;
  while ((match = M3U8_RE.exec(text)) !== null) {
    const value = match[1]?.trim();
    if (value) {
      values.add(value);
    }
  }

  return [...values];
}

function uniqueResolvedUrls(values: Iterable<string>, baseUrl: string): string[] {
  const resolved = new Set<string>();
  for (const value of values) {
    try {
      resolved.add(new URL(value, baseUrl).href);
    } catch {
      // Ignore malformed values.
    }
  }

  return [...resolved];
}

function extractFrameUrls(text: string, baseUrl: string): string[] {
  const $ = load(text);
  const values = new Set<string>();

  $('iframe[src], frame[src]').each((_index, element) => {
    const src = $(element).attr('src');
    if (src) {
      values.add(src);
    }
  });

  SCRIPTED_IFRAME_RE.lastIndex = 0;
  let scripted: RegExpExecArray | null = null;
  while ((scripted = SCRIPTED_IFRAME_RE.exec(text)) !== null) {
    const src = scripted[1]?.trim();
    if (src) {
      values.add(src);
    }
  }

  return uniqueResolvedUrls(values, baseUrl);
}

function extractDomainCandidates(text: string): string[] {
  DOMAIN_RE.lastIndex = 0;
  const values = new Set<string>();

  let match: RegExpExecArray | null = null;
  while ((match = DOMAIN_RE.exec(text)) !== null) {
    const value = match[0]?.trim();
    if (value && !value.includes('{v')) {
      values.add(value.replace(/\/+$/, ''));
    }
  }

  return [...values];
}

function materializePlaylistCandidates(text: string, pageUrl: string): string[] {
  const direct = allM3u8InText(text);
  const domains = extractDomainCandidates(text);
  const values = new Set<string>();

  for (const url of direct) {
    if (!url.includes('{v')) {
      values.add(url);
      continue;
    }

    for (const domain of domains) {
      values.add(url.replace(/^https:\/\/[^/]+/i, domain));
    }
  }

  return uniqueResolvedUrls(values, pageUrl);
}

function buildPageHeaders(referer: string, userAgent: string): Record<string, string> {
  const origin = new URL(referer).origin;
  return {
    'User-Agent': userAgent,
    Referer: referer,
    Origin: origin,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };
}

function choosePlaylistCandidate(candidates: string[], pageUrl: string): string | null {
  if (candidates.length == 0) {
    return null;
  }

  const currentHost = new URL(pageUrl).hostname;

  for (const candidate of candidates) {
    if (new URL(candidate).hostname === currentHost) {
      return candidate;
    }
  }

  return candidates[0] ?? null;
}

export type ResolvedM3u8Result = {
  playlist: string;
  referer: string;
};

async function resolvePlaylistFromPage(opts: PullM3u8FromPageOptions & {
  currentUrl: string;
  currentReferer: string;
  depth: number;
  visited: Set<string>;
}): Promise<ResolvedM3u8Result | null> {
  const { proxiedFetcher, currentUrl, currentReferer, userAgent, depth, visited } = opts;

  if (depth > MAX_DEPTH || visited.has(currentUrl)) {
    return null;
  }
  visited.add(currentUrl);

  const pageHeaders = buildPageHeaders(currentReferer, userAgent);
  const response = await proxiedFetcher.full<string>(currentUrl, {
    headers: pageHeaders,
  });
  const body = typeof response.body === 'string' ? response.body : String(response.body ?? '');
  const finalUrl = response.finalUrl ?? currentUrl;

  const playlists = materializePlaylistCandidates(body, finalUrl);
  const playlist = choosePlaylistCandidate(playlists, finalUrl);
  if (playlist) {
    return { playlist, referer: finalUrl };
  }

  const frames = extractFrameUrls(body, finalUrl);
  for (const frameUrl of frames) {
    const resolved = await resolvePlaylistFromPage({
      ...opts,
      currentUrl: frameUrl,
      currentReferer: finalUrl,
      depth: depth + 1,
      visited,
    });
    if (resolved) {
      return resolved;
    }
  }

  return null;
}

export type PullM3u8FromPageOptions = {
  proxiedFetcher: UseableFetcher;
  pageUrl: string;
  referer: string;
  userAgent: string;
};

/**
 * Fetches an embed page and tries to find a playable HLS URL.
 */
export async function pullM3u8FromEmbedPage(opts: PullM3u8FromPageOptions): Promise<string> {
  const resolved = await resolveM3u8FromEmbedPage(opts);
  return resolved.playlist;
}

export async function resolveM3u8FromEmbedPage(
  opts: PullM3u8FromPageOptions,
): Promise<ResolvedM3u8Result> {
  const resolved = await resolvePlaylistFromPage({
    ...opts,
    currentUrl: opts.pageUrl,
    currentReferer: opts.referer,
    depth: 0,
    visited: new Set<string>(),
  });

  if (resolved) {
    return resolved;
  }

  throw new NotFoundError('No m3u8 found in embed page');
}
