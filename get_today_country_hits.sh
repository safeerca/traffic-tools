#!/bin/bash

# ==========================================================
# TODAY's traffic by country (best-effort)
# - Auto-checks geoiplookup
# - Attempts apt install if missing
# - IPv6 handled explicitly
# - Always quiet
# ==========================================================

LOG_DIR="$(pwd)"
TODAY=$(date +"%d/%b/%Y")

TMP_DIR="$(pwd)/.traffic_tmp_$$"
mkdir -p "$TMP_DIR" || exit 1
trap 'rm -rf "$TMP_DIR"' EXIT

IP_COUNTS="$TMP_DIR/ip_counts.txt"
IP_COUNTRY="$TMP_DIR/ip_country.tsv"
COUNTRY_HITS="$TMP_DIR/country_hits.tsv"

# ----------------------------------------------------------
# 0) Ensure geoiplookup exists (best-effort)
# ----------------------------------------------------------
HAS_GEOIP=1
if ! command -v geoiplookup >/dev/null 2>&1; then
  HAS_GEOIP=0

  # Try apt-based install only
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq geoip-bin >/dev/null 2>&1
    command -v geoiplookup >/dev/null 2>&1 && HAS_GEOIP=1
  fi
fi

# ----------------------------------------------------------
# 1) Extract TODAY's IP hit counts
# ----------------------------------------------------------
(
  grep -h "\[$TODAY:" "$LOG_DIR"/*access.log 2>/dev/null
  zgrep -h "\[$TODAY:" "$LOG_DIR"/*access.log.*.gz 2>/dev/null
) \
| awk '{print $1}' \
| sort \
| uniq -c \
| awk '{print $2 "\t" $1}' \
> "$IP_COUNTS"

[ ! -s "$IP_COUNTS" ] && exit 0

# ----------------------------------------------------------
# 2) Map IPs to countries (best-effort)
# ----------------------------------------------------------
while read -r ip count; do
  # IPv6 detection
  if [[ "$ip" == *:* ]]; then
    echo -e "$ip\tIPv6\tUnresolved"
    continue
  fi

  # No GeoIP available
  if [ "$HAS_GEOIP" -eq 0 ]; then
    echo -e "$ip\tUnknown\tGeoIP missing"
    continue
  fi

  geoiplookup "$ip" | awk -v ip="$ip" '
    /GeoIP Country Edition:/ {
      if ($0 ~ /not found|IP Address/) {
        cc="Unknown"; cname="Unknown"
      } else {
        split($0, a, ": ")
        split(a[2], b, ", ")
        cc=b[1]
        cname=b[2]
      }
    }
    END {
      if (cc=="") cc="Unknown"
      if (cname=="") cname="Unknown"
      print ip "\t" cc "\t" cname
    }'
done < "$IP_COUNTS" > "$IP_COUNTRY"

# ----------------------------------------------------------
# 3) Aggregate by country (informational only)
# ----------------------------------------------------------
awk '
  NR==FNR {
    ip_cc[$1]=$2"\t"$3
    next
  }
  {
    split(ip_cc[$1], c, "\t")
    totals[c[1]"\t"c[2]] += $2
  }
  END {
    for (k in totals)
      print k "\t" totals[k]
  }
' "$IP_COUNTRY" "$IP_COUNTS" \
| sort -nr -k3,3 > "$COUNTRY_HITS"

# ----------------------------------------------------------
# 4) Output
# ----------------------------------------------------------
column -t "$COUNTRY_HITS"
