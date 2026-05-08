#!/usr/bin/env bash
# Saunasto visit-log query helpers.
# Usage: bash d1-migrations/queries.sh [recent | top-uas | by-ip <ip> | by-ua <pattern> | bots-today | humans-today | ai-agents | full <id>]
set -euo pipefail
cd "$(dirname "$0")/.."

DB=saunasto-visits
EXEC() { wrangler d1 execute "$DB" --remote --json --command "$1" 2>/dev/null; }
PARSE='import json,sys; d=json.load(sys.stdin); rows=d[0].get("results",[]) if isinstance(d,list) else d.get("results",[])
if not rows: print("(no rows)")
else:
    cols=list(rows[0].keys())
    print(" | ".join(c.ljust(22)[:22] for c in cols))
    print("-+-".join("-"*22 for _ in cols))
    [print(" | ".join(str(r[c] or "")[:22].ljust(22) for c in cols)) for r in rows]'

cmd="${1:-recent}"
case "$cmd" in
  recent)
    EXEC "SELECT id, datetime(ts/1000,'unixepoch') AS at, path, substr(ua,1,40) AS ua, ip, country, colo
          FROM visits ORDER BY ts DESC LIMIT 25;" | python3 -c "$PARSE"
    ;;
  top-uas)
    EXEC "SELECT substr(ua,1,80) AS ua, COUNT(*) AS hits
          FROM visits WHERE ts > (strftime('%s','now')-86400)*1000
          GROUP BY substr(ua,1,80) ORDER BY hits DESC LIMIT 20;" | python3 -c "$PARSE"
    ;;
  top-ips)
    EXEC "SELECT ip, country, COUNT(*) AS hits, MAX(datetime(ts/1000,'unixepoch')) AS last_seen
          FROM visits WHERE ts > (strftime('%s','now')-86400)*1000
          GROUP BY ip ORDER BY hits DESC LIMIT 20;" | python3 -c "$PARSE"
    ;;
  by-ip)
    ip="${2:?usage: $0 by-ip <ip>}"
    EXEC "SELECT id, datetime(ts/1000,'unixepoch') AS at, path, substr(ua,1,60) AS ua, country
          FROM visits WHERE ip = '$ip' ORDER BY ts DESC LIMIT 50;" | python3 -c "$PARSE"
    ;;
  by-ua)
    pat="${2:?usage: $0 by-ua <pattern>}"
    EXEC "SELECT id, datetime(ts/1000,'unixepoch') AS at, path, ip, country, colo
          FROM visits WHERE ua LIKE '%$pat%' ORDER BY ts DESC LIMIT 50;" | python3 -c "$PARSE"
    ;;
  bots-today)
    EXEC "SELECT id, datetime(ts/1000,'unixepoch') AS at, substr(ua,1,55) AS ua, ip, country, path
          FROM visits
          WHERE ts > (strftime('%s','now')-86400)*1000
          AND (ua LIKE '%bot%' OR ua LIKE '%Bot%' OR ua LIKE '%spider%' OR ua LIKE '%crawler%' OR ua LIKE '%curl%' OR ua LIKE '%http-client%' OR ua = '')
          ORDER BY ts DESC LIMIT 50;" | python3 -c "$PARSE"
    ;;
  humans-today)
    EXEC "SELECT datetime(ts/1000,'unixepoch') AS at, substr(ua,1,55) AS ua, ip, country, path
          FROM visits
          WHERE ts > (strftime('%s','now')-86400)*1000
          AND ua NOT LIKE '%bot%' AND ua NOT LIKE '%Bot%' AND ua NOT LIKE '%spider%'
          AND ua NOT LIKE '%crawler%' AND ua NOT LIKE '%curl%' AND ua NOT LIKE '%http-client%'
          AND ua != ''
          ORDER BY ts DESC LIMIT 50;" | python3 -c "$PARSE"
    ;;
  ai-agents)
    EXEC "SELECT datetime(ts/1000,'unixepoch') AS at, substr(ua,1,55) AS ua, ip, country, path
          FROM visits
          WHERE ua LIKE '%GPTBot%' OR ua LIKE '%ClaudeBot%' OR ua LIKE '%Claude-Web%'
             OR ua LIKE '%PerplexityBot%' OR ua LIKE '%OAI-SearchBot%'
             OR ua LIKE '%Google-Extended%' OR ua LIKE '%Applebot-Extended%'
             OR ua LIKE '%Bytespider%' OR ua LIKE '%CCBot%'
             OR ua LIKE '%meta-externalagent%'
          ORDER BY ts DESC LIMIT 50;" | python3 -c "$PARSE"
    ;;
  full)
    id="${2:?usage: $0 full <id>}"
    EXEC "SELECT * FROM visits WHERE id = $id;" | python3 -c "
import json, sys
d = json.load(sys.stdin)
rows = d[0].get('results', []) if isinstance(d, list) else d.get('results', [])
if not rows: print('(no row id=$id)')
else:
    for k, v in rows[0].items(): print(f'  {k:<10} {v}')"
    ;;
  schema)
    EXEC "SELECT sql FROM sqlite_master WHERE type IN ('table','index') AND tbl_name='visits';" | python3 -c "$PARSE"
    ;;
  count)
    EXEC "SELECT
            COUNT(*) AS total,
            (SELECT COUNT(*) FROM visits WHERE ts > (strftime('%s','now')-86400)*1000) AS last_24h,
            (SELECT COUNT(DISTINCT ip) FROM visits WHERE ts > (strftime('%s','now')-86400)*1000) AS unique_ips_24h
          FROM visits;" | python3 -c "$PARSE"
    ;;
  *)
    cat <<USAGE
Usage: bash d1-migrations/queries.sh <command> [args]

  recent           last 25 visits
  top-uas          top 20 user agents in last 24h
  top-ips          top 20 IPs in last 24h
  by-ip <ip>       all visits from one IP
  by-ua <pat>      visits whose UA contains <pat>  (e.g. GPTBot, Claude, Mozilla)
  bots-today       last 24h, bot UAs only
  humans-today     last 24h, real-browser UAs only
  ai-agents        all-time, AI search crawlers (GPTBot, ClaudeBot, etc.)
  full <id>        every column for visit id <id>
  schema           show table + index DDL
  count            totals + last-24h breakdown
USAGE
    exit 1
    ;;
esac
