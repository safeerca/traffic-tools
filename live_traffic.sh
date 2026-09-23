#!/bin/bash

SSH_USER="systeam"

echo "=============================================="
echo " CLOUDWAYS DYNAMIC LIVE TRAFFIC STREAMER"
echo "=============================================="
echo

# Read prompts directly from /dev/tty to support 'curl | bash'
printf "Enter Target Server IP: "
read -r TARGET_IP < /dev/tty
TARGET_IP=$(echo "$TARGET_IP" | tr -d '[:space:]')

if [ -z "$TARGET_IP" ]; then
    echo
    echo "[ERROR] Target Server IP is required."
    exit 1
fi

printf "Save output to a text file on Proxy Server? [y/N]: "
read -r SAVE_LOG < /dev/tty
SAVE_LOG=$(echo "$SAVE_LOG" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

LOG_OUTPUT_PATH=""
if [[ "$SAVE_LOG" == "y" || "$SAVE_LOG" == "yes" ]]; then
    printf "Enter proxy log filename (default: live_stream.log): "
    read -r LOG_OUTPUT_FILE < /dev/tty
    LOG_OUTPUT_FILE=$(echo "$LOG_OUTPUT_FILE" | tr -d '[:space:]')
    
    if [[ -z "$LOG_OUTPUT_FILE" || "$LOG_OUTPUT_FILE" == "y" || "$LOG_OUTPUT_FILE" == "yes" ]]; then
        LOG_OUTPUT_FILE="live_stream.log"
    fi
    
    LOG_OUTPUT_PATH="${PWD}/${LOG_OUTPUT_FILE}"
    echo "Live stream will be saved to: ${LOG_OUTPUT_PATH}"
fi

echo
echo "Connecting to $TARGET_IP..."
sleep 1

# Clear Proxy Terminal Screen ONCE at launch
clear

while true; do
  {
  ssh -q -t \
      -o ConnectTimeout=15 \
      -o StrictHostKeyChecking=no \
      "$SSH_USER@$TARGET_IP" \
      "TERM=xterm-256color sudo bash -s -- '$TARGET_IP'" < <(cat << 'REMOTE_SCRIPT'
SERVER_IP="$1"

# Detect top 3 active PHP-FPM pools with aggregate CPU% and MEM%
TOP_POOLS_DATA=$(ps -eo user:30,%cpu,%mem,args | awk '/php-fpm: pool/ {
    user=$1; cpu=$2; mem=$3
    if (user != "root" && user != "www-data") {
        for(i=1;i<=NF;i++) {
            if($i=="pool") {
                p=$(i+1)
                cpu_sum[p] += cpu
                mem_sum[p] += mem
                break
            }
        }
    }
}
END {
    for (p in cpu_sum)
        printf "%.1f %.1f %s\n", cpu_sum[p], mem_sum[p], p
}' | sort -nr -k1,1 | head -n 3)

APP1=$(echo "$TOP_POOLS_DATA" | sed -n '1p' | awk '{print $3}')
CPU1=$(echo "$TOP_POOLS_DATA" | sed -n '1p' | awk '{print $1}')
MEM1=$(echo "$TOP_POOLS_DATA" | sed -n '1p' | awk '{print $2}')

APP2=$(echo "$TOP_POOLS_DATA" | sed -n '2p' | awk '{print $3}')
CPU2=$(echo "$TOP_POOLS_DATA" | sed -n '2p' | awk '{print $1}')
MEM2=$(echo "$TOP_POOLS_DATA" | sed -n '2p' | awk '{print $2}')

APP3=$(echo "$TOP_POOLS_DATA" | sed -n '3p' | awk '{print $3}')
CPU3=$(echo "$TOP_POOLS_DATA" | sed -n '3p' | awk '{print $1}')
MEM3=$(echo "$TOP_POOLS_DATA" | sed -n '3p' | awk '{print $2}')

if [ -z "$APP1" ]; then
    echo "[ERROR] No active PHP-FPM pools detected on server."
    exit 1
fi

# Function to extract top client IP and hit count from recent logs
get_top_ip_summary() {
    local app="$1"
    local log_file
    log_file=$(find "/home/master/applications/${app}/logs" -maxdepth 1 -type f -name 'backend_wordpress-*.access.log' ! -name '*.gz' 2>/devnull | head -n 1)
    if [ -n "$log_file" ]; then
        tail -n 1000 "$log_file" 2>/devnull | awk -v sip="$SERVER_IP" '
        $1 != sip && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ { hits[$1]++ }
        END {
            max=0; top=""
            for (ip in hits) {
                if (hits[ip] > max) { max=hits[ip]; top=ip }
            }
            if (top != "") printf "%s (%d hits)", top, max
            else print "None"
        }'
    else
        echo "None"
    fi
}

IP1=$(get_top_ip_summary "$APP1")
IP2=$(get_top_ip_summary "$APP2")
IP3=$(get_top_ip_summary "$APP3")

echo "========================================================================================================================="
echo " CLOUDWAYS LIVE TRAFFIC MONITOR | SERVER IP: $SERVER_IP"
echo " Detected Top CPU Pools at $(date -u '+%H:%M:%S UTC'):"
[ -n "$APP1" ] && printf "   - Pool 1 (Cyan)   : %-12s | CPU: %5.1f%% | MEM: %4.1f%% | Top IP: %s\n" "$APP1" "${CPU1:-0.0}" "${MEM1:-0.0}" "${IP1:-None}"
[ -n "$APP2" ] && printf "   - Pool 2 (Yellow) : %-12s | CPU: %5.1f%% | MEM: %4.1f%% | Top IP: %s\n" "$APP2" "${CPU2:-0.0}" "${MEM2:-0.0}" "${IP2:-None}"
[ -n "$APP3" ] && printf "   - Pool 3 (Magenta): %-12s | CPU: %5.1f%% | MEM: %4.1f%% | Top IP: %s\n" "$APP3" "${CPU3:-0.0}" "${MEM3:-0.0}" "${IP3:-None}"
echo "========================================================================================================================="
echo

LOG_FILES=""
for APP in $APP1 $APP2 $APP3; do
    MATCH=$(find "/home/master/applications/${APP}/logs" -maxdepth 1 -type f -name 'backend_wordpress-*.access.log' ! -name '*.gz' 2>/devnull | head -n 1)
    if [ -n "$MATCH" ]; then
        LOG_FILES="$LOG_FILES $MATCH"
    fi
done

if [ -z "$LOG_FILES" ]; then
    echo "[ERROR] Could not locate active backend access logs."
    exit 1
fi

# ANSI Colors
C_CYAN="\033[1;36m"
C_YELLOW="\033[1;33m"
C_MAGENTA="\033[1;35m"
C_RED="\033[1;31m"
C_BG_RED="\033[41;1;37m"
C_RESET="\033[0m"

# Stream line-by-line for 60s, showing last 5 log lines for immediate context
timeout 60s stdbuf -oL -eL tail -n 5 -F $LOG_FILES 2>/devnull | awk \
  -v myip="$SERVER_IP" \
  -v a1="$APP1" -v a2="$APP2" -v a3="$APP3" \
  -v c_a1="$C_CYAN" -v c_a2="$C_YELLOW" -v c_a3="$C_MAGENTA" \
  -v c_red="$C_RED" -v c_bg_red="$C_BG_RED" -v c_reset="$C_RESET" '
/==>/ {
    if (a1 != "" && index($0, a1) > 0) current_app = a1
    else if (a2 != "" && index($0, a2) > 0) current_app = a2
    else if (a3 != "" && index($0, a3) > 0) current_app = a3
    next
}
{
    ip = $1
    method = ""
    url = ""
    status = "-"
    ts_short = ""
    ua_short = "-"

    # Extract Timestamp [...]
    t_start = index($0, "[")
    t_end = index($0, "]")
    if (t_start > 0 && t_end > t_start) {
        ts = substr($0, t_start + 1, t_end - t_start - 1)
        split(ts, ts_parts, ":")
        if (length(ts_parts) >= 3) {
            ts_short = ts_parts[2] ":" ts_parts[3] ":" substr(ts_parts[4], 1, 2)
        } else {
            ts_short = ts
        }
    }

    # Extract HTTP Request Method, URL, and Status Code
    q1 = index($0, "\"")
    if (q1 > 0) {
        s = substr($0, q1 + 1)
        q2 = index(s, "\"")
        if (q2 > 0) {
            req = substr(s, 1, q2 - 1)
            split(req, r_parts, " ")
            method = r_parts[1]
            url = r_parts[2]

            # Parse HTTP Status Code
            after_req = substr(s, q2 + 1)
            split(after_req, a_parts, / +/)
            for (i=1; i<=4; i++) {
                if (a_parts[i] ~ /^[1-5][0-9][0-9]$/) {
                    status = a_parts[i]
                    break
                }
            }
        }
    }

    # Truncate overly long paths cleanly
    if (length(url) > 65) {
        url = substr(url, 1, 62) "..."
    }

    # Extract clean User-Agent
    num_quotes = split($0, q_parts, "\"")
    if (num_quotes >= 6) {
        raw_ua = q_parts[6]
    } else if (num_quotes >= 4) {
        raw_ua = q_parts[4]
    } else {
        raw_ua = ""
    }

    if (raw_ua != "" && raw_ua != "-") {
        if (raw_ua ~ /Barkrowler/) ua_short = "Barkrowler Bot"
        else if (raw_ua ~ /AhrefsBot/) ua_short = "AhrefsBot"
        else if (raw_ua ~ /MainWP/) ua_short = "MainWP Bot"
        else if (raw_ua ~ /Googlebot/) ua_short = "Googlebot"
        else if (raw_ua ~ /SemrushBot/) ua_short = "SemrushBot"
        else if (raw_ua ~ /Bytespider/) ua_short = "Bytespider Bot"
        else if (raw_ua ~ /paessler/ || raw_ua ~ /PRTG/) ua_short = "PRTG Monitor"
        else if (raw_ua ~ /curl/) ua_short = "curl"
        else if (raw_ua ~ /Sensu/ || raw_ua ~ /sensu/) ua_short = "Sensu Monitor"
        else if (raw_ua ~ /meta-webindexer/) ua_short = "Meta Crawler"
        else {
            split(raw_ua, ua_tokens, " ")
            n_tokens = length(ua_tokens)
            if (n_tokens >= 2) {
                ua_short = ua_tokens[n_tokens-1] " " ua_tokens[n_tokens]
            } else {
                ua_short = raw_ua
            }
            gsub(/[()\[\]]/, "", ua_short)
        }
    } else {
        ua_short = "-"
    }

    active_app = (current_app != "") ? current_app : a1

    # Increment real-time IP hit counter per pool
    if (ip != "" && active_app != "") {
        ip_hits[active_app, ip]++
    }

    color_row = c_reset
    if (active_app == a1) color_row = c_a1
    else if (active_app == a2) color_row = c_a2
    else if (active_app == a3) color_row = c_a3

    # Format Status Code Color (Red for 5xx)
    status_fmt = status
    if (status ~ /^5/) {
        status_fmt = c_bg_red status color_row
    }

    if (ip == myip) {
        ip_label = c_red ip " [SERVER IP]" color_row
    } else {
        cnt = ip_hits[active_app, ip]
        if (cnt >= 3) {
            ip_label = sprintf("%s (%d hits)", ip, cnt)
        } else {
            ip_label = ip
        }
    }

    if (method != "" && active_app != "") {
        printf "%s[%s] [%-10s] %-6s | Status: %s | IP: %-34s | Path: %-65s | UA: %s%s\n", 
               color_row, ts_short, active_app, method, status_fmt, ip_label, url, ua_short, c_reset
        fflush()
    }
}'
REMOTE_SCRIPT
)
  } | if [ -n "$LOG_OUTPUT_PATH" ]; then tee -a "$LOG_OUTPUT_PATH"; else cat; fi

  sleep 1
done
