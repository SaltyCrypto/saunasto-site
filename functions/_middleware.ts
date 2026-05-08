// Logs every non-asset request to the saunasto-visits D1 database so we
// have raw UA + IP forensics for citation verification, abuse audits,
// and rough first-party analytics.
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

// Log only meaningful Saunasto navigation paths plus a few well-known
// metadata files (so we can prove a given AI agent ever fetched them).
const LOG_META = new Set(['/robots.txt', '/sitemap.xml', '/llms.txt', '/llms-full.txt']);

export const onRequest: PagesFunction<Env> = async (context) => {
  const { request, env, next, waitUntil } = context;
  const url = new URL(request.url);

  // Decide whether to log this request.
  const isAsset = ASSET_RX.test(url.pathname);
  const isMeta  = LOG_META.has(url.pathname);
  const shouldLog = !isAsset || isMeta;

  if (shouldLog && env.DB) {
    // Pull all the forensics we can. Cloudflare attaches a `cf` object
    // with country/asn/colo/bot management info on every request that
    // crossed the edge — the IP itself comes from CF-Connecting-IP.
    const cf = (request as any).cf || {};
    const log = {
      ts:        Date.now(),
      path:      url.pathname + (url.search || ''),
      ip:        request.headers.get('cf-connecting-ip')
                  || request.headers.get('x-real-ip')
                  || '',
      ua:        request.headers.get('user-agent') || '',
      country:   cf.country || null,
      asn:       cf.asn ?? null,
      asn_org:   cf.asOrganization || null,
      colo:      cf.colo || null,
      referer:   request.headers.get('referer') || null,
      method:    request.method,
      bot_score: cf.botManagement?.score ?? null,
    };

    // Fire-and-forget. .catch swallows so a DB outage never breaks the
    // page render. waitUntil keeps the Worker alive long enough for
    // the insert to complete after the response has streamed.
    waitUntil(
      env.DB.prepare(
        `INSERT INTO visits
           (ts, path, ip, ua, country, asn, asn_org, colo, referer, method, bot_score)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)`
      )
      .bind(log.ts, log.path, log.ip, log.ua, log.country,
            log.asn, log.asn_org, log.colo, log.referer, log.method, log.bot_score)
      .run()
      .catch(() => undefined)
    );
  }

  return next();
};
