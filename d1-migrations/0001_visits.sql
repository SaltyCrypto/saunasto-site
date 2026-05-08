CREATE TABLE IF NOT EXISTS visits (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ts          INTEGER NOT NULL,           -- unix ms
    path        TEXT    NOT NULL,
    ip          TEXT    NOT NULL,
    ua          TEXT    NOT NULL,
    country     TEXT,
    asn         INTEGER,
    asn_org     TEXT,
    colo        TEXT,
    referer     TEXT,
    method      TEXT,
    status      INTEGER,
    bot_score   INTEGER                     -- cf bot management score (1=bot, 99=human)
);
CREATE INDEX IF NOT EXISTS idx_visits_ts      ON visits(ts);
CREATE INDEX IF NOT EXISTS idx_visits_ip      ON visits(ip);
CREATE INDEX IF NOT EXISTS idx_visits_ua      ON visits(ua);
CREATE INDEX IF NOT EXISTS idx_visits_country ON visits(country);
CREATE INDEX IF NOT EXISTS idx_visits_path    ON visits(path);
