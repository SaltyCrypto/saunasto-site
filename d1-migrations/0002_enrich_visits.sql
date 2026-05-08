-- Schema upgrade: enrichment fields for cross-domain (saunasto.com + atika.app)
-- visit logging.
--
-- Adds:
--   host                — distinguishes saunasto.com vs atika.app vs *.pages.dev
--   verified_bot_category — Cloudflare's free verified-bot signal. Non-null
--                          means CF cryptographically confirmed the bot
--                          (e.g., "Search Engine Crawler" for Googlebot,
--                          "Generative AI" for GPTBot/ClaudeBot). UA spoofers
--                          show NULL.
--   tls_version, tls_cipher, tls_hello_length — TLS handshake metadata.
--                          Catches HTTP scrapers impersonating browsers via UA.
--                          (cf.botManagement.ja4 needs paid Bot Mgmt so we
--                          skip it for now and use these instead.)
ALTER TABLE visits ADD COLUMN host TEXT;
ALTER TABLE visits ADD COLUMN verified_bot_category TEXT;
ALTER TABLE visits ADD COLUMN tls_version TEXT;
ALTER TABLE visits ADD COLUMN tls_cipher TEXT;
ALTER TABLE visits ADD COLUMN tls_hello_length INTEGER;

CREATE INDEX IF NOT EXISTS idx_visits_host                ON visits(host);
CREATE INDEX IF NOT EXISTS idx_visits_verified_bot_cat    ON visits(verified_bot_category);
