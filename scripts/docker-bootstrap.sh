#!/bin/bash
# Hermes one-shot bootstrap — runs once on first container boot (as hermes user).
# Sets up ops-watchdog cron job if missing.
set -e

HERMES_HOME="${HERMES_HOME:-/opt/data}"
CRON_FILE="$HERMES_HOME/cron/jobs.json"

ensure_ops_watchdog() {
  # Source script in image
  local img_script="/opt/hermes/scripts/ops-watchdog.sh"
  [ ! -f "$img_script" ] && return 0

  # Ensure it exists in the volume (cron resolves scripts relative to $HERMES_HOME/scripts/)
  local vol_script="$HERMES_HOME/scripts/ops-watchdog.sh"
  if [ ! -f "$vol_script" ]; then
    mkdir -p "$HERMES_HOME/scripts"
    cp "$img_script" "$vol_script"
    chmod +x "$vol_script"
  fi

  # Check if cron job already exists
  if [ -f "$CRON_FILE" ] && grep -q "ops-watchdog" "$CRON_FILE" 2>/dev/null; then
    return 0
  fi

  # Create the cron job
  hermes cron create "0 8 * * *" \
    --name "ops-watchdog" \
    --script "ops-watchdog.sh" \
    --no-agent \
    --deliver "origin" 2>/dev/null || true
}

ensure_ops_watchdog
