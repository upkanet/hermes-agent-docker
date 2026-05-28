#!/bin/bash
# ============================================================
# Sync config files vers data_runtime (source -> runtime)
#
# But:
# - rendre explicite quel fichier est pris par Hermes au runtime
# - permettre de propager volontairement les changements de config/
#
# Usage:
#   ./scripts/sync-runtime-config.sh              # copie seulement les fichiers manquants
#   ./scripts/sync-runtime-config.sh --force      # ecrase runtime avec config/
#   ./scripts/sync-runtime-config.sh --dry-run
# ============================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SRC_DIR="config"
DST_DIR="data_runtime"
DRY_RUN=0
FORCE=0

usage() {
  cat <<'EOF'
Usage: ./scripts/sync-runtime-config.sh [options]

Options:
  --force      Ecrase data_runtime/{config.yaml,.env} avec config/
  --dry-run    Affiche les actions sans ecrire
  -h, --help   Affiche cette aide
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Option inconnue: $1"
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$DST_DIR"

sync_one() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [[ ! -f "$src" ]]; then
    echo "[WARN] Source absente: $src ($label)"
    return 0
  fi

  if [[ -f "$dst" && "$FORCE" -ne 1 ]]; then
    if cmp -s "$src" "$dst"; then
      echo "[OK] Deja synchronise: $dst"
    else
      echo "[SKIP] Runtime different, non ecrase sans --force: $dst"
    fi
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY] cp $src $dst"
  else
    cp "$src" "$dst"
    echo "[SYNC] $src -> $dst"
  fi
}

sync_one "$SRC_DIR/config.yaml" "$DST_DIR/config.yaml" "config"
sync_one "$SRC_DIR/.env" "$DST_DIR/.env" "env"

echo "Termine."
