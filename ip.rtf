{\rtf1\ansi\ansicpg1252\cocoartf2822
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/bin/bash\
\
# ==========================================================\
# TODAY's country-wise traffic from Nginx access logs\
# Cloudways-safe | Handles .gz logs | No join | GeoIP legacy\
# ==========================================================\
\
LOG_DIR="$(pwd)"\
TODAY=$(date +"%d/%b/%Y")\
\
IP_COUNTS="/tmp/ip_counts_today.txt"\
IP_COUNTRY="/tmp/ip_country_full_today.tsv"\
COUNTRY_HITS="/tmp/country_hits_today.tsv"\
\
echo "=================================================="\
echo "Date       : $TODAY"\
echo "Log source : $LOG_DIR"\
echo "=================================================="\
\
# ----------------------------------------------------------\
# 1) Extract TODAY's IP hit counts from access logs\
# ----------------------------------------------------------\
echo "[1/4] Extracting today's IP hit counts..."\
\
(\
  # Plain access logs\
  grep -h "\\[$TODAY:" "$LOG_DIR"/*access.log 2>/dev/null\
\
  # Rotated gzip access logs\
  zgrep -h "\\[$TODAY:" "$LOG_DIR"/*access.log.*.gz 2>/dev/null\
) \\\
| awk '\{print $1\}' \\\
| sort \\\
| uniq -c \\\
| awk '\{print $2 "\\t" $1\}' \\\
> "$IP_COUNTS"\
\
echo "  \uc0\u8594  IP counts written to $IP_COUNTS"\
\
# ----------------------------------------------------------\
# 2) Map IPs to countries using geoiplookup\
# ----------------------------------------------------------\
echo "[2/4] Mapping IPs to countries..."\
\
while read -r ip count; do\
  geoiplookup "$ip" | awk -v ip="$ip" '\
    /GeoIP Country Edition:/ \{\
      if ($0 ~ /not found|can.t resolve|IP Address/) \{\
        cc="Unknown"; cname="Unknown"\
      \} else \{\
        split($0, a, ": ")\
        split(a[2], b, ", ")\
        cc=b[1]\
        cname=b[2]\
      \}\
    \}\
    END \{\
      if (cc=="") cc="Unknown"\
      if (cname=="") cname="Unknown"\
      print ip "\\t" cc "\\t" cname\
    \}'\
done < "$IP_COUNTS" > "$IP_COUNTRY"\
\
echo "  \uc0\u8594  IP-to-country map written to $IP_COUNTRY"\
\
# ----------------------------------------------------------\
# 3) Aggregate today's hits by country (AWK hash map)\
# ----------------------------------------------------------\
echo "[3/4] Aggregating today's traffic by country..."\
\
awk '\
  NR==FNR \{\
    ip_cc[$1] = $2 "\\t" $3\
    next\
  \}\
  \{\
    split(ip_cc[$1], c, "\\t")\
    if (c[1] == "") \{\
      c[1] = "Unknown"\
      c[2] = "Unknown"\
    \}\
    totals[c[1] "\\t" c[2]] += $2\
  \}\
  END \{\
    for (k in totals)\
      print k "\\t" totals[k]\
  \}\
' "$IP_COUNTRY" "$IP_COUNTS" \\\
| sort -nr -k3,3 > "$COUNTRY_HITS"\
\
echo "  \uc0\u8594  Country totals written to $COUNTRY_HITS"\
\
# ----------------------------------------------------------\
# 4) Display result\
# ----------------------------------------------------------\
echo\
echo "TODAY'S TRAFFIC BY COUNTRY"\
echo "--------------------------------------------------"\
column -t "$COUNTRY_HITS"\
echo "--------------------------------------------------"\
echo "Done."\
}