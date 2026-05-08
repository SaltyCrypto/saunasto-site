// Logs every non-asset request to the saunasto-visits D1 database so we
// have raw UA + IP forensics for citation verification, AI-agent audit,
// abuse forensics, and rough first-party analytics. The same database
// is shared with atika.app — the `host` column distinguishes them.
//
// Runs as a Pages Function middleware: every request to saunasto.com
// passes through here before the static asset is served. We use
// context.waitUntil() so the DB write does not block response render —
// the visitor's experience is unchanged even if the DB is slow or
// unavailable.

interface Env {
  DB: D1Database;
}

// Match anything that's clearly an asset request. Skipping these keeps
// volume sane (the homepage alone pulls ~5 asset URLs per page view).
const ASSET_RX = /\.(css|js|svg|png|jpg|jpeg|webp|gif|ico|woff2?|ttf|map)$/i;

// Log only meaningful navigation paths plus a few well-known metadata
// files (so we can prove which AI agent fetched each manifest).
const LOG_META = new Set([
  '/robots.txt', '/sitemap.xml', '/llms.txt', '/llms-full.txt',
  '/data/saunasto-100.json',
]);

export const onRequest: PagesFunction<Env> = async (context) => {
  const { request, env, next, waitUntil } = context;
  const url = new URL(request.url);

  const isAsset = ASSET_RX.test(url.pathname);
  const isMeta  = LOG_META.has(url.pathname);
  const shouldLog = !isAsset || isMeta;

  if (shouldLog && env.DB) {
    // Pull all the forensics Cloudflare exposes on the free plan. The
    // `cf` object is populated for every request that traversed the
    // edge. `verifiedBotCategory` is Cloudflare's free verified-bot
    // signal — non-null means CF cryptographically confirmed the bot's
    // identity via reverse-DNS round-trip (real Googlebot / GPTBot
    // vs UA impersonator). TLS fields catch HTTP scrapers spoofing
    // browser UAs.
    const cf = (request as any).cf || {};
    const log = {
      ts:                Date.now(),
      host:              request.headers.get('host') || '',
      path:              url.pathname + (url.search || ''),
      ip:                request.headers.get('cf-connecting-ip')
                          || request.headers.get('x-real-ip')
                          || '',
      ua:                request.headers.get('user-agent') || '',
      country:           cf.country || null,
      asn:               cf.asn ?? null,
      asn_org:           cf.asOrganization || null,
      colo:              cf.colo || null,
      referer:           request.headers.get('referer') || null,
      method:            request.method,
      // `||null` (not `??null`) so empty strings collapse to NULL — keeps
      // queries like `WHERE verified_bot_category IS NOT NULL` clean.
      verified_bot_cat:  cf.verifiedBotCategory || null,
      tls_version:       cf.tlsVersion || null,
      tls_cipher:        cf.tlsCipher || null,
      tls_hello_length:  (cf.tlsClientHelloLength && cf.tlsClientHelloLength > 0)
                          ? cf.tlsClientHelloLength : null,
      // bot_score is paid-Bot-Management only; left in place for
      // forward compat. Will be NULL on the free plan.
      bot_score:         cf.botManagement?.score ?? null,
    };

    waitUntil(
      env.DB.prepare(
        `INSERT INTO visits
           (ts, host, path, ip, ua, country, asn, asn_org, colo, referer, method,
            verified_bot_category, tls_version, tls_cipher, tls_hello_length, bot_score)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
      )
      .bind(log.ts, log.host, log.path, log.ip, log.ua, log.country,
            log.asn, log.asn_org, log.colo, log.referer, log.method,
            log.verified_bot_cat, log.tls_version, log.tls_cipher,
            log.tls_hello_length, log.bot_score)
      .run()
      .catch(() => undefined)
    );
  }

  return next();
};
