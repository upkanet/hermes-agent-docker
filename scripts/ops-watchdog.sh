#!/bin/bash
# ============================================================
# Hermes Ops Watchdog
# Surveillance automatique: disque, health, DB, logs
# Usage: ./ops-watchdog.sh
# ============================================================
set -euo pipefail

DATA_DIR="/opt/data"
LOG_DIR="$DATA_DIR/logs"
CRON_OUT_DIR="$DATA_DIR/cron/output"
STATE_DB="$DATA_DIR/state.db"
HEALTH_URL="http://localhost:8642/health"

WARN_DISK_MB=500
WARN_DB_MB=50
WARN_CRON_STALE_HOURS=48

issues=()
warnings=()

log() { echo "[ops-watchdog] $*"; }

check_health() {
  local status
  status=$(curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null || echo "FAIL")
  if [[ "$status" == *"ok"* ]]; then
    log "Health: OK"
  else
    issues+=("Health endpoint UNREACHABLE: $status")
  fi
}

check_disk() {
  local used_kb used_mb
  used_kb=$(du -sk "$DATA_DIR" 2>/dev/null | cut -f1)
  used_mb=$((used_kb / 1024))
  log "Disk usage: ${used_mb}M"
  if [[ "$used_mb" -gt "$WARN_DISK_MB" ]]; then
    warnings+=("Disk usage ${used_mb}M > ${WARN_DISK_MB}M threshold")
  fi
}

check_db() {
  if [[ -f "$STATE_DB" ]]; then
    local db_size
    db_size=$(stat -c%s "$STATE_DB" 2>/dev/null || stat -f%z "$STATE_DB" 2>/dev/null)
    local db_size_mb=$((db_size / 1048576))
    log "state.db: ${db_size_mb}M"
    if [[ "$db_size_mb" -gt "$WARN_DB_MB" ]]; then
      warnings+=("state.db size ${db_size_mb}M > ${WARN_DB_MB}M threshold")
    fi
  else
    log "state.db: not found (first run?)"
  fi
}

check_cron_stale() {
  if [[ -d "$CRON_OUT_DIR" ]]; then
    local stale_count
    stale_count=$(find "$CRON_OUT_DIR" -type f -mtime "+$((WARN_CRON_STALE_HOURS / 24))" 2>/dev/null | wc -l)
    log "Stale cron outputs (>${WARN_CRON_STALE_HOURS}h): ${stale_count}"
    if [[ "$stale_count" -gt 5 ]]; then
      warnings+=("${stale_count} stale cron outputs in $CRON_OUT_DIR")
    fi
  fi
}

report() {
  local msg=""

  if [[ ${#issues[@]} -gt 0 ]]; then
    msg+="🔴 OPS WATCHDOG — ISSUES\n"
    for i in "${issues[@]}"; do msg+="  • $i\n"; done
  fi
  if [[ ${#warnings[@]} -gt 0 ]]; then
    msg+="🟡 OPS WATCHDOG — WARNINGS\n"
    for w in "${warnings[@]}"; do msg+="  • $w\n"; done
  fi

  if [[ -z "$msg" ]]; then
    log "All clear — no issues or warnings."
    return 0
  fi

  echo -e "$msg"

  local tg_output
  tg_output=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN:-}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_ALLOWED_USERS%%,*}" \
    --data-urlencode "text=$msg" \
    --data-urlencode "parse_mode=Markdown" 2>/dev/null)
  if echo "$tg_output" | grep -q '"ok":true'; then
    log "Telegram alert sent."
  else
    log "Telegram send failed (maybe no TELEGRAM_BOT_TOKEN?). Skipping."
  fi
}

# ── Main ──────────────────────────────────────────────────────
log "Starting ops watchdog..."
check_health
check_disk
check_db
check_cron_stale
report
log "Done."
