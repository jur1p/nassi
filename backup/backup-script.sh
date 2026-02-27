#!/bin/bash
# ============================================
# ZFS Snapshot + Send → USB-levy backup
# ============================================
# Käyttö: ./backup-script.sh
# Cron:   0 3 * * * /mnt/tank/apps/compose/backup/backup-script.sh >> /var/log/zfs-backup.log 2>&1
# ============================================

set -euo pipefail

# --- Asetukset ---
POOL="tank"
USB_MOUNT="/mnt/usb-backup"
DATASETS=("apps" "nextcloud" "shared")  # Kriittiset datasetit (ei media - liian iso)
DATE=$(date +%Y-%m-%d_%H-%M)
KEEP_SNAPSHOTS=7    # Montako snapshotia pidetään
KEEP_FILES_DAYS=30  # Montako päivää USB:n .zfs-tiedostoja pidetään

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
for DS in "${DATASETS[@]}"; do
    FULL="${POOL}/${DS}"
    SNAP="${FULL}@backup-${DATE}"
    DEST="${USB_MOUNT}/${DS}"
    TRACKER="${DEST}/latest-snapshot.txt"

    log_info "Snapshot: ${SNAP}"
    zfs snapshot -r "${SNAP}"

    # Luo kohdekansio
    mkdir -p "${DEST}"

    # Tarkista onko edellinen backup olemassa inkrementaalia varten
    if [ -f "${TRACKER}" ]; then
        PREV=$(cat "${TRACKER}")
        # Varmista että edellinen snapshot on vielä olemassa
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

    # Merkitse viimeisin onnistunut snapshot
    echo "${SNAP}" > "${TRACKER}"

    log_info "${DS} backup valmis"
done

# --- Siivoa vanhat snapshotit ---
log_info "Siivotaan vanhoja snapshoteja..."

for DS in "${DATASETS[@]}"; do
    FULL="${POOL}/${DS}"

    # Listaa backup-snapshotit vanhimmasta uusimpaan
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
