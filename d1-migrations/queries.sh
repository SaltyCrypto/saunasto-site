#!/usr/bin/env bash
# Saunasto + Atika visit-log query helpers.
# Usage: bash d1-migrations/queries.sh <command> [args]
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
    [print(" | ".join(str(r[c] if r[c] is not None else "")[:22].ljust(22) for c in cols)) for r in rows]'

cmd="${1:-recent}"
case "$cmd" in
  recent)
    EXEC "SELECT id, datetime(ts/1000,'unixepoch') AS at, host, path, substr(ua,1,30) AS ua, ip, country
          FROM visits ORDER BY ts DESC LIMIT 25;" | python3 -c "$PARSE" ;;
  count)
    EXEC "SELECT
            (SELECT COUNT(*) FROM visits) AS total,
            (SELECT COUNT(*) FROM visits WHERE ts > (strftime('%s','now')-86400)*1000) AS last_24h,
            (SELECT COUNT(DISTINCT ip) FROM visits WHERE ts > (strftime('%s','now')-86400)*1000) AS unique_ips_24h;" \
      | python3 -c "$PARSE" ;;
  by-host)
    EXEC "SELECT host, COUNT(*) AS hits, COUNT(DISTINCT ip) AS unique_ips
          FROM visits WHERE ts > (strftime('%s','now')-86400)*1000 AND host IS NOT NULL AND host != ''
          GROUP BY host ORDER BY hits DESC;" | python3 -c "$PARSE" ;;
  for-host)
    h="${2:?usage: $0 for-host <hostname>}"
    EXEC "SELECT id, datetime(ts/1000,'unixepoch') AS at, path, substr(ua,1,40) AS ua, ip, country
          FROM visits WHERE host = '$h' ORDER BY ts DESC LIMIT 25;" | python3 -c "$PARSE" ;;
  top-uas)
    EXEC "SELECT substr(ua,1,80) AS ua, COUNT(*) AS hits
          FROM visits WHERE ts > (strftime('%s','now')-86400)*1000
          GROUP BY substr(ua,1,80) ORDER BY hits DESC LIMIT 20;" | python3 -c "$PARSE" ;;
  top-ips)
    EXEC "SELECT ip, country, asn_org, COUNT(*) AS hits, MAX(datetime(ts/1000,'unixepoch')) AS last_seen
          FROM visits WHERE ts > (strftime('%s','now')-86400)*1000
          GROUP BY ip ORDER BY hits DESC LIMIT 20;" | python3 -c "$PARSE" ;;
  verified-bots)
    EXEC "SELECT host, verified_bot_category, COUNT(*) AS hits, substr(ua,1,40) AS ua_sample
          FROM visits WHERE verified_bot_category IS NOT NULL AND verified_bot_category != ''
          GROUP BY host, verified_bot_category, substr(ua,1,40) ORDER BY hits DESC LIMIT 25;" \
      | python3 -c "$PARSE" ;;
  by-ip)
    ip="${2:?usage: $0 by-ip <ip>}"
    EXEC "SELECT id, datetime(ts/1000,'unixepoch') AS at, host, path, substr(ua,1,55) AS ua, country, verified_bot_category
          FROM visits WHERE ip = '$ip' ORDER BY ts DESC LIMIT 50;" | python3 -c "$PARSE" ;;
  by-ua)
    pat="${2:?usage: $0 by-ua <pattern>}"
    EXEC "SELECT id, datetime(ts/1000,'unixepoch') AS at, host, path, ip, country, verified_bot_category
          FROM visits WHERE ua LIKE '%$pat%' ORDER BY ts DESC LIMIT 50;" | python3 -c "$PARSE" ;;
  ai-agents)
    EXEC "SELECT datetime(ts/1000,'unixepoch') AS at, host, substr(ua,1,55) AS ua, ip, country, verified_bot_category
          FROM visits
          WHERE ua LIKE '%GPTBot%' OR ua LIKE '%ClaudeBot%' OR ua LIKE '%Claude-Web%'
             OR ua LIKE '%PerplexityBot%' OR ua LIKE '%OAI-SearchBot%'
             OR ua LIKE '%Google-Extended%' OR ua LIKE '%Applebot-Extended%'
             OR ua LIKE '%Bytespider%' OR ua LIKE '%CCBot%' OR ua LIKE '%meta-externalagent%'
          ORDER BY ts DESC LIMIT 50;" | python3 -c "$PARSE" ;;
  full)
    id="${2:?usage: $0 full <id>}"
    EXEC "SELECT * FROM visits WHERE id = $id;" | python3 -c "
import json, sys
d = json.load(sys.stdin)
rows = d[0].get('results', []) if isinstance(d, list) else d.get('results', [])
[print(f'  {k:<26} {v}') for k,v in (rows[0].items() if rows else [])]"
    ;;
  schema)
    EXEC "SELECT sql FROM sqlite_master WHERE tbl_name='visits';" | python3 -c "$PARSE" ;;
  *)
    cat <<USAGE
Usage: bash d1-migrations/queries.sh <command> [args]

  recent              last 25 visits across both sites
  count               totals + last-24h + unique IPs
  by-host             per-domain breakdown last 24h
  for-host <host>     visits for one specific host (saunasto.com / atika.app / *.pages.dev)
  top-uas             top 20 user agents in last 24h
  top-ips             top 20 IPs in last 24h
  verified-bots       Cloudflare-verified bots only (real GPTBot, Googlebot, etc)
  by-ip <ip>          all visits from one IP
  by-ua <pat>         visits whose UA contains <pat>
  ai-agents           UA-pattern AI crawlers (verified or not)
  full <id>           every column for visit id <id>
  schema              show DDL
USAGE
    exit 1 ;;
esac
