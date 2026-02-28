#!/bin/bash
# ============================================
# ZFS Snapshot + Send → USB-levy backup
# ============================================
# Käyttö: ./backup-script.sh
# Cron:   0 3 * * * /mnt/tank/apps/compose/backup/backup-script.sh >> /var/log/zfs-backup.log 2>&1
# ============================================

set -euo pipefail

# --- Asetukset ---
USB_MOUNT="/mnt/usb-backup"
DATE=$(date +%Y-%m-%d_%H-%M)
KEEP_SNAPSHOTS=7
KEEP_FILES_DAYS=30

# Backupoitavat datasetit (pool/dataset)
# Kaikki tank-poolissa koska stripe ei tarjoa redundanssia
BACKUP_DATASETS=(
    "tank/apps"
    "tank/nextcloud"
    "tank/shared"
)

# --- Logitus ---
log_info()  { echo "[INFO]  $(date '+%H:%M:%S') $*"; }
log_warn()  { echo "[WARN]  $(date '+%H:%M:%S') $*"; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*"; }

log_info "Backup aloitettu"

# --- Tarkista USB-levy ---
if ! mountpoint -q "${USB_MOUNT}"; then
    log_error "USB-levy ei ole mountattu: ${USB_MOUNT}"
    echo "Mounttaa levy: mount /dev/sdX1 ${USB_MOUNT}"
    exit 1
fi

# --- Snapshot + Send jokainen dataset ---
for FULL in "${BACKUP_DATASETS[@]}"; do
    DS_DIR="${FULL//\//-}"
    SNAP="${FULL}@backup-${DATE}"
    DEST="${USB_MOUNT}/${DS_DIR}"
    TRACKER="${DEST}/latest-snapshot.txt"

    if ! zfs list -H -o name "${FULL}" >/dev/null 2>&1; then
        log_warn "Dataset ${FULL} ei löydy, ohitetaan"
        continue
    fi

    log_info "Snapshot: ${SNAP}"
    zfs snapshot -r "${SNAP}"

    mkdir -p "${DEST}"

    if [ -f "${TRACKER}" ]; then
        PREV=$(cat "${TRACKER}")
        if zfs list -t snapshot -H -o name "${PREV}" >/dev/null 2>&1; then
            log_info "Inkrementaalinen send: ${PREV} → ${SNAP}"
            zfs send -i "${PREV}" "${SNAP}" > "${DEST}/incr-${DATE}.zfs"
        else
            log_warn "Edellinen snapshot ${PREV} ei löydy, tehdään täysi backup"
            zfs send "${SNAP}" > "${DEST}/full-${DATE}.zfs"
        fi
    else
        log_info "Ensimmäinen backup, täysi send: ${SNAP}"
        zfs send "${SNAP}" > "${DEST}/full-${DATE}.zfs"
    fi

    echo "${SNAP}" > "${TRACKER}"
    log_info "${FULL} backup valmis"
done

# --- Siivoa vanhat snapshotit ---
log_info "Siivotaan vanhoja snapshoteja..."

for FULL in "${BACKUP_DATASETS[@]}"; do
    if ! zfs list -H -o name "${FULL}" >/dev/null 2>&1; then
        continue
    fi

    SNAPS=$(zfs list -t snapshot -o name -s creation -H "${FULL}" 2>/dev/null \
        | grep "@backup-" || true)

    COUNT=$(echo "${SNAPS}" | grep -c . || true)

    if [ "${COUNT}" -gt "${KEEP_SNAPSHOTS}" ]; then
        DELETE_COUNT=$((COUNT - KEEP_SNAPSHOTS))
        echo "${SNAPS}" | head -n "${DELETE_COUNT}" | while read -r OLD_SNAP; do
            log_warn "Poistetaan vanha snapshot: ${OLD_SNAP}"
            zfs destroy "${OLD_SNAP}"
        done
    fi
done

# --- Siivoa vanhat backup-tiedostot USB:ltä ---
log_info "Siivotaan vanhoja backup-tiedostoja USB:ltä..."
find "${USB_MOUNT}" -name "*.zfs" -mtime "+${KEEP_FILES_DAYS}" -delete 2>/dev/null || true

log_info "Backup valmis"
echo "---"
