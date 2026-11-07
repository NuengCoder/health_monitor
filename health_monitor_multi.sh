#!/bin/bash
# ============================================================
#  health_monitor_multi.sh
#  Cross-platform health monitor: Linux / macOS / Termux
#  Author : YILAN
#  Date   : 2026-11-06
# ============================================================
set -euo pipefail

# ---------- Global configuration ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
CSV_FILE="${LOG_DIR}/metrics.csv"
ALERT_LOG="${LOG_DIR}/alert.log"
INTERVAL=5
CPU_THRESH=80
MEM_THRESH=80
DISK_THRESH=90
EMIT_JSON=0

mkdir -p "$LOG_DIR"
[[ -f "$CSV_FILE"  ]] || echo "timestamp,platform,cpu_pct,mem_pct,disk_pct,rx_kbps,tx_kbps" > "$CSV_FILE"
[[ -f "$ALERT_LOG" ]] || : > "$ALERT_LOG"

# ---------- Module 0: Platform detection ----------
detect_platform() {
    # Termux check FIRST (it runs on Linux but is special)
    if [[ -n "${TERMUX_VERSION:-}" ]] || [[ "${PREFIX:-}" == *"com.termux"* ]]; then
        echo "termux"
        return
    fi
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}

PLATFORM="$(detect_platform)"

# ---------- Module 1: Argument parsing ----------
usage() {
    cat <<EOF
Usage: $0 [-i interval] [-c cpu%] [-m mem%] [-d disk%] [-j]
Platform detected: ${PLATFORM}
EOF
}

while getopts ":i:c:m:d:jh" opt; do
    case "$opt" in
        i) INTERVAL="$OPTARG" ;;
        c) CPU_THRESH="$OPTARG" ;;
        m) MEM_THRESH="$OPTARG" ;;
        d) DISK_THRESH="$OPTARG" ;;
        j) EMIT_JSON=1 ;;
        h) usage; exit 0 ;;
        \?) echo "Unknown: -$OPTARG" >&2; exit 1 ;;
        :)  echo "Option -$OPTARG requires arg" >&2; exit 1 ;;
    esac
done

log_alert() { printf '[%s] %s\n' "$(date '+%F %T')" "$1" >> "$ALERT_LOG"; }

# ============================================================
# CPU SAMPLING — platform-specific
# ============================================================
cpu_linux() {
    local s1 s2
    s1=$(awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat)
    sleep 1
    s2=$(awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat)
    awk -v s1="$s1" -v s2="$s2" 'BEGIN {
        split(s1,a," "); split(s2,b," ")
        t1=0; t2=0; for(i=1;i<=8;i++){t1+=a[i];t2+=b[i]}
        idle1=a[4]+a[5]; idle2=b[4]+b[5]
        dt=t2-t1; didle=idle2-idle1
        if(dt<=0){print "0.00";exit}
        printf "%.2f", (dt-didle)*100/dt
    }'
}

cpu_macos() {
    # macOS top -l 1 gives a CPU usage line; extract the "idle" percentage
    # and subtract from 100. This is less precise than /proc sampling but
    # works on stock macOS without extra tools.
    top -l 1 -n 0 | awk '/CPU usage/ {
        gsub("%","",$7);  # $7 is like "95.0%"
        printf "%.2f", 100 - $7
    }'
}

cpu_termux() {
    # Termux on non-rooted Android often cannot read /proc/stat
    # due to SELinux restrictions. Report N/A.
    echo "N/A"
}

# ============================================================
# MEMORY SAMPLING
# ============================================================
mem_linux() {
    awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2}
         END{ if(t>0) printf "%.2f",(t-a)*100/t; else print "0.00" }' /proc/meminfo
}

mem_macos() {
    # macOS: get total via sysctl hw.memsize, then parse vm_stat
    # for free+inactive+speculative+purgeable pages
    local total_bytes avail_bytes page_size
    total_bytes=$(sysctl -n hw.memsize)
    page_size=$(vm_stat | head -1 | sed -E 's/.*page size of ([0-9]+) bytes.*/\1/')
    [[ -z "$page_size" ]] && page_size=16384  # Apple Silicon default

    avail_bytes=$(vm_stat | awk -v ps="$page_size" '
        /Pages free:/        {gsub(/\./,"",$3); free=$3}
        /Pages inactive:/    {gsub(/\./,"",$3); inact=$3}
        /Pages speculative:/ {gsub(/\./,"",$3); spec=$3}
        /Pages purgeable:/   {gsub(/\./,"",$3); purge=$3}
        END { printf "%.0f", (free+inact+spec+purge)*ps }
    ')
    awk -v t="$total_bytes" -v a="$avail_bytes" 'BEGIN{
        if(t>0) printf "%.2f",(t-a)*100/t; else print "0.00"
    }'
}

mem_termux() { echo "N/A"; }

# ============================================================
# DISK SAMPLING
# ============================================================
disk_linux() {
    df -P -x tmpfs -x devtmpfs | awk 'NR>1{gsub("%","",$5); if($5+0>max)max=$5+0}
        END{printf "%.2f", max+0}'
}

disk_macos() {
    # macOS df -P works similarly; exclude devfs and map auto_home
    df -P -x devfs -x autofs 2>/dev/null | awk 'NR>1{gsub("%","",$5); if($5+0>max)max=$5+0}
        END{printf "%.2f", max+0}'
}

disk_termux() {
    df -P 2>/dev/null | awk 'NR>1{gsub("%","",$5); if($5+0>max)max=$5+0}
        END{printf "%.2f", max+0}'
}

# ============================================================
# NETWORK SAMPLING
# ============================================================
net_linux() {
    local s1 s2
    s1=$(awk 'NR>2{gsub(":","",$1); if($1=="lo")next; rx+=$2; tx+=$10}
              END{print rx+0, tx+0}' /proc/net/dev)
    sleep 1
    s2=$(awk 'NR>2{gsub(":","",$1); if($1=="lo")next; rx+=$2; tx+=$10}
              END{print rx+0, tx+0}' /proc/net/dev)
    awk -v s1="$s1" -v s2="$s2" 'BEGIN{
        split(s1,a," "); split(s2,b," ")
        rx=(b[1]-a[1])*8/1000; tx=(b[2]-a[2])*8/1000
        printf "%.0f %.0f", rx, tx
    }'
}

net_macos() {
    # macOS: use netstat -ib and sum bytes across interfaces
    # Column positions: $7 = Ibytes, $10 = Obytes (varies by macOS version)
    local s1 s2
    s1=$(netstat -ib 2>/dev/null | awk 'NR>1 && $1!~/^(lo|gif|stf|awdl|llw|utun)/ {
        ibytes+=$7; obytes+=$10
    } END{print ibytes+0, obytes+0}')
    sleep 1
    s2=$(netstat -ib 2>/dev/null | awk 'NR>1 && $1!~/^(lo|gif|stf|awdl|llw|utun)/ {
        ibytes+=$7; obytes+=$10
    } END{print ibytes+0, obytes+0}')
    awk -v s1="$s1" -v s2="$s2" 'BEGIN{
        split(s1,a," "); split(s2,b," ")
        rx=(b[1]-a[1])*8/1000; tx=(b[2]-a[2])*8/1000
        printf "%.0f %.0f", rx, tx
    }'
}

net_termux() { echo "N/A N/A"; }

# ============================================================
# DISPATCHERS — call the right function per platform
# ============================================================
get_cpu()  { case "$PLATFORM" in macos) cpu_macos;;  termux) cpu_termux;;  *) cpu_linux;;  esac; }
get_mem()  { case "$PLATFORM" in macos) mem_macos;;  termux) mem_termux;;  *) mem_linux;;  esac; }
get_disk() { case "$PLATFORM" in macos) disk_macos;; termux) disk_termux;; *) disk_linux;; esac; }
get_net()  { case "$PLATFORM" in macos) net_macos;;  termux) net_termux;;  *) net_linux;;  esac; }

# ============================================================
# Threshold evaluation (handles "N/A")
# ============================================================
ge() { awk -v a="$1" -v b="$2" 'BEGIN{ exit !(a+0>=b+0) }'; }

evaluate() {
    local cpu="$1" mem="$2" disk="$3"
    local alerts=""
    [[ "$cpu"  != "N/A" ]] && ge "$cpu"  "$CPU_THRESH"  && alerts+=" CPU=${cpu}%"
    [[ "$mem"  != "N/A" ]] && ge "$mem"  "$MEM_THRESH"  && alerts+=" MEM=${mem}%"
    [[ "$disk" != "N/A" ]] && ge "$disk" "$DISK_THRESH" && alerts+=" DISK=${disk}%"
    if [[ -n "$alerts" ]]; then
        log_alert "ALERT:${alerts}"
        printf '  >> ALERT:%s\n' "$alerts"
    fi
}

report_csv() {
    printf '%s,%s,%s,%s,%s,%s,%s\n' \
        "$(date '+%F %T')" "$PLATFORM" "$1" "$2" "$3" "$4" "$5" >> "$CSV_FILE"
}

report_json() {
    printf '{"timestamp":"%s","platform":"%s","cpu_pct":"%s","mem_pct":"%s","disk_pct":"%s","rx_kbps":"%s","tx_kbps":"%s"}\n' \
        "$(date '+%F %T')" "$PLATFORM" "$1" "$2" "$3" "$4" "$5"
}

cleanup() {
    echo "[health_monitor] stopped. Platform: $PLATFORM"
    echo "  CSV: $CSV_FILE"
}
trap cleanup EXIT

# ---------- Main ----------
echo "============================================"
echo " Health Monitor — Platform: $PLATFORM"
echo " Interval: ${INTERVAL}s  CPU: ${CPU_THRESH}%  MEM: ${MEM_THRESH}%  DISK: ${DISK_THRESH}%"
echo "============================================"

while true; do
    CPU=$(get_cpu)
    MEM=$(get_mem)
    DISK=$(get_disk)
    read -r RX TX < <(get_net)

    printf 'CPU=%s%%  MEM=%s%%  DISK=%s%%  RX=%s kbit/s  TX=%s kbit/s\n' \
        "$CPU" "$MEM" "$DISK" "$RX" "$TX"

    evaluate "$CPU" "$MEM" "$DISK"
    report_csv "$CPU" "$MEM" "$DISK" "$RX" "$TX"
    
    # Output JSON if the -j flag was used
    [[ "$EMIT_JSON" -eq 1 ]] && report_json "$CPU" "$MEM" "$DISK" "$RX" "$TX"

    sleep "$INTERVAL"
done