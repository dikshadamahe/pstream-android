import { flags } from '@/entrypoint/utils/targets';
import { makeEmbed } from '@/providers/base';
import { resolveM3u8FromEmbedPage } from '@/providers/utils/m3u8FromEmbedPage';
import { createM3U8ProxyUrl } from '@/utils/proxy';

const REF = 'https://vsembed.ru/';

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/**
 * Resolves a vsembed/vidsrc embed page to an HLS playlist.
 * @see backend/providers-api/docs/CUSTOM_EMBED_INTEGRATION.md §1
 */
export const vidsrcembedIframe = makeEmbed({
  id: 'vidsrcembed-iframe',
  name: 'VidSrc embed (iframe -> m3u8)',
  rank: 330,
  disabled: false,
  flags: [flags.CORS_ALLOWED],
  async scrape(ctx) {
    const resolved = await resolveM3u8FromEmbedPage({
      proxiedFetcher: ctx.proxiedFetcher,
      pageUrl: ctx.url,
      referer: REF,
      userAgent: UA,
    });

    const headers: Record<string, string> = {
      referer: resolved.referer,
      origin: new URL(resolved.referer).origin,
    };

    return {
      stream: [
        {
          type: 'hls',
          id: 'primary',
          playlist: createM3U8ProxyUrl(resolved.playlist, ctx.features, headers),
          flags: [flags.CORS_ALLOWED],
          captions: [],
          headers,
        },
      ],
    };
  },
});
