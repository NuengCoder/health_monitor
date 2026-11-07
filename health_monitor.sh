#!/bin/bash
# ============================================================
#  health_monitor.sh
#  Linux system health monitor (CPU / MEM / DISK / NET)
#  Author : YILAN
#  Date   : 2026-11-07
#  Usage  : ./health_monitor.sh [-i interval] [-c cpu%] [-m mem%] [-d disk%] [-j]
#  Purpose: Sample system metrics from /proc, evaluate against
#           thresholds, append to CSV, write alerts to a log.
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
[[ -f "$CSV_FILE"  ]] || echo "timestamp,cpu_pct,mem_pct,disk_pct,rx_kbps,tx_kbps" > "$CSV_FILE"
[[ -f "$ALERT_LOG" ]] || : > "$ALERT_LOG"

# ---------- Module 1: Argument parsing ----------
usage() {
    cat <<EOF
Usage: $0 [-i interval] [-c cpu%] [-m mem%] [-d disk%] [-j]
  -i  sampling interval in seconds (default 5)
  -c  CPU alert threshold percent  (default 80)
  -m  memory alert threshold percent (default 80)
  -d  disk alert threshold percent (default 90)
  -j  also print a JSON snapshot each cycle
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
        \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
        :)  echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
    esac
done

# ---------- Module 2: Logging helper ----------
log_alert() {
    local msg="$1"
    printf '[%s] %s\n' "$(date '+%F %T')" "$msg" >> "$ALERT_LOG"
}

# ---------- Module 3: CPU sampling ----------
# /proc/stat first line: cpu user nice system idle iowait irq softirq steal ...
# Take two samples, compute busy/total delta as a percentage.
read_cpu_snapshot() {
    awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat
}

cpu_pct() {
    local s1 s2
    s1=$(read_cpu_snapshot)
    sleep 1
    s2=$(read_cpu_snapshot)
    awk -v s1="$s1" -v s2="$s2" 'BEGIN {
        split(s1,a," "); split(s2,b," ")
        # a[1]=user a[2]=nice a[3]=system a[4]=idle a[5]=iowait a[6]=irq a[7]=softirq a[8]=steal
        t1=0; t2=0
        for (i=1;i<=8;i++) { t1+=a[i]; t2+=b[i] }
        idle1=a[4]+a[5]; idle2=b[4]+b[5]
        dt=t2-t1; didle=idle2-idle1
        if (dt<=0) { print 0; exit }
        printf "%.2f", (dt-didle)*100/dt
    }'
}

# ---------- Module 4: Memory sampling ----------
# MemTotal and MemAvailable in kB; usage = (Total-Avail)/Total*100
mem_pct() {
    awk '/^MemTotal:/     {t=$2}
         /^MemAvailable:/ {a=$2}
         END { if (t>0) printf "%.2f", (t-a)*100/t; else print 0 }' /proc/meminfo
}

# ---------- Module 5: Disk sampling ----------
# Highest used percentage across real (non-tmpfs) local filesystems.
disk_pct() {
    df -P -x tmpfs -x devtmpfs | awk 'NR>1 {
        gsub("%","",$5)
        if ($5+0 > max) max=$5+0
    } END { printf "%.2f", max+0 }'
}

# ---------- Module 6: Network sampling ----------
# /proc/net/dev columns: iface: rx_bytes rx_pkts ... tx_bytes tx_pkts ...
# Sum rx/tx bytes, take two samples 1s apart, report kbit/s.
net_snapshot() {
    awk 'NR>2 {
        gsub(":","",$1)
        if ($1=="lo") next
        rx+=$2; tx+=$10
    } END { print rx+0, tx+0 }' /proc/net/dev
}

net_rates() {
    local r1 t1 r2 t2
    read -r r1 t1 < <(net_snapshot)
    sleep 1
    read -r r2 t2 < <(net_snapshot)
    local drx=$(( r2 - r1 ))
    local dtx=$(( t2 - t1 ))
    # Convert bytes/sec to kbit/s: bytes * 8 / 1000
    local rx_kbps=$(( drx * 8 / 1000 ))
    local tx_kbps=$(( dtx * 8 / 1000 ))
    echo "$rx_kbps $tx_kbps"
}

# ---------- Module 7: Threshold evaluation ----------
# Bash can't compare decimals; delegate to awk.
ge() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0>=b+0)}'; }

evaluate() {
    local cpu="$1" mem="$2" disk="$3"
    local alerts=""
    ge "$cpu"  "$CPU_THRESH"  && alerts+=" CPU=${cpu}%"
    ge "$mem"  "$MEM_THRESH"  && alerts+=" MEM=${mem}%"
    ge "$disk" "$DISK_THRESH" && alerts+=" DISK=${disk}%"
    if [[ -n "$alerts" ]]; then
        log_alert "ALERT:${alerts}"
        printf '  >> ALERT triggered:%s\n' "$alerts"
    fi
}

# ---------- Module 8: CSV + JSON report ----------
report_csv() {
    local ts cpu mem disk rx tx
    ts=$(date '+%F %T')
    cpu="$1"; mem="$2"; disk="$3"
    rx="$4";  tx="$5"
    printf '%s,%s,%s,%s,%s,%s\n' "$ts" "$cpu" "$mem" "$disk" "$rx" "$tx" >> "$CSV_FILE"
}

report_json() {
    local ts cpu mem disk rx tx
    ts=$(date '+%F %T')
    cpu="$1"; mem="$2"; disk="$3"
    rx="$4";  tx="$5"
    printf '{"timestamp":"%s","cpu_pct":%s,"mem_pct":%s,"disk_pct":%s,"rx_kbps":%s,"tx_kbps":%s}\n' \
        "$ts" "$cpu" "$mem" "$disk" "$rx" "$tx"
}

# ---------- Cleanup on exit ----------
cleanup() {
    echo
    echo "[health_monitor] stopped at $(date '+%F %T')."
    echo "  CSV  : $CSV_FILE"
    echo "  Alert: $ALERT_LOG"
}
trap cleanup EXIT

# ---------- Main loop ----------
echo "============================================"
echo " Health Monitor (Linux /proc)"
echo " Interval: ${INTERVAL}s   CPU: ${CPU_THRESH}%   MEM: ${MEM_THRESH}%   DISK: ${DISK_THRESH}%"
echo " CSV: $CSV_FILE"
echo " Log: $ALERT_LOG"
echo " Press Ctrl+C to stop."
echo "============================================"

while true; do
    CPU=$(cpu_pct)
    MEM=$(mem_pct)
    DISK=$(disk_pct)
    read -r RX TX < <(net_rates)

    printf 'CPU=%s%%  MEM=%s%%  DISK=%s%%  RX=%s kbit/s  TX=%s kbit/s\n' \
        "$CPU" "$MEM" "$DISK" "$RX" "$TX"

    evaluate "$CPU" "$MEM" "$DISK"
    report_csv  "$CPU" "$MEM" "$DISK" "$RX" "$TX"
    [[ "$EMIT_JSON" -eq 1 ]] && report_json "$CPU" "$MEM" "$DISK" "$RX" "$TX"

    sleep "$INTERVAL"
done