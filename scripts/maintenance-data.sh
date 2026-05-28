#!/bin/bash
# ============================================================
# Hermes data maintenance
# - backup rotatif de data_runtime
# - prune des archives data_archive agees de plus de N jours
#
# Usage:
#   ./scripts/maintenance-data.sh
#   ./scripts/maintenance-data.sh --dry-run
#   ./scripts/maintenance-data.sh --keep 7 --archive-days 45
#
# Variables optionnelles:
#   BACKUP_KEEP=5
#   ARCHIVE_PRUNE_DAYS=30
# ============================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DATA_RUNTIME_DIR="data_runtime"
BACKUP_DIR="backups"
ARCHIVE_ROOT="data_archive"

BACKUP_KEEP="${BACKUP_KEEP:-5}"
ARCHIVE_PRUNE_DAYS="${ARCHIVE_PRUNE_DAYS:-30}"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./scripts/maintenance-data.sh [options]

Options:
  --dry-run           Affiche les actions sans modifier le disque
  --keep N            Nombre de backups a conserver (defaut: 5)
  --archive-days N    Supprime les archives > N jours (defaut: 30)
  -h, --help          Affiche cette aide
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --keep)
      BACKUP_KEEP="$2"
      shift 2
      ;;
    --archive-days)
      ARCHIVE_PRUNE_DAYS="$2"
      shift 2
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

if ! [[ "$BACKUP_KEEP" =~ ^[0-9]+$ ]] || [ "$BACKUP_KEEP" -lt 1 ]; then
  echo "--keep doit etre un entier >= 1"
  exit 1
fi

if ! [[ "$ARCHIVE_PRUNE_DAYS" =~ ^[0-9]+$ ]] || [ "$ARCHIVE_PRUNE_DAYS" -lt 1 ]; then
  echo "--archive-days doit etre un entier >= 1"
  exit 1
fi

if [ ! -d "$DATA_RUNTIME_DIR" ]; then
  echo "Dossier introuvable: $DATA_RUNTIME_DIR"
  exit 1
fi

mkdir -p "$BACKUP_DIR" "$ARCHIVE_ROOT"

ts="$(date +%Y%m%d_%H%M%S)"
backup_file="$BACKUP_DIR/hermes_data_runtime_${ts}.tgz"

echo "[1/3] Backup data_runtime -> $backup_file"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: tar -czf $backup_file $DATA_RUNTIME_DIR"
else
  tar -czf "$backup_file" "$DATA_RUNTIME_DIR"
fi

echo "[2/3] Rotation backups (keep=$BACKUP_KEEP)"
mapfile -t backup_files < <(ls -1t "$BACKUP_DIR"/hermes_data_runtime_*.tgz 2>/dev/null || true)
if [ "${#backup_files[@]}" -le "$BACKUP_KEEP" ]; then
  echo "Aucun backup a supprimer (${#backup_files[@]} present(s))."
else
  for old_file in "${backup_files[@]:$BACKUP_KEEP}"; do
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY RUN: rm -f $old_file"
    else
      rm -f "$old_file"
      echo "Supprime: $old_file"
    fi
  done
fi

echo "[3/3] Prune archives data_archive > ${ARCHIVE_PRUNE_DAYS} jours"
mapfile -t old_archives < <(find "$ARCHIVE_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime "+$ARCHIVE_PRUNE_DAYS" -print 2>/dev/null || true)
if [ "${#old_archives[@]}" -eq 0 ]; then
  echo "Aucune archive a supprimer."
else
  for archive_dir in "${old_archives[@]}"; do
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY RUN: rm -rf $archive_dir"
    else
      rm -rf "$archive_dir"
      echo "Supprime: $archive_dir"
    fi
  done
fi

echo "Termine."
