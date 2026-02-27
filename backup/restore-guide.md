# Palautus- ja levynvaihto-ohje

## Tilanne 1: Levy hajonnut → vaihda uusi

ZFS mirror kestää yhden levyn hajoamisen ilman datan menetystä.

### Tunnista hajonnut levy

```bash
zpool status tank
```

Tuloste näyttää:
```
  pool: tank
 state: DEGRADED
config:
  NAME        STATE     READ WRITE CKSUM
  tank        DEGRADED     0     0     0
    mirror-0  DEGRADED     0     0     0
      sda     ONLINE       0     0     0
      sdb     UNAVAIL      0     0     0    ← HAJONNUT
```

### Vaihda levy

```bash
# 1. Sammuta palvelin ja vaihda fyysinen levy

# 2. Käynnistä ja tarkista uuden levyn nimi
lsblk

# 3. Korvaa hajonnut levy
zpool replace tank /dev/sdb /dev/sdX    # sdX = uusi levy

# 4. Seuraa resilvering-prosessia
zpool status tank
# scan: resilver in progress since ...
#   123G scanned at 456M/s, 78G issued at 234M/s, 1.5T total

# 5. Odota kunnes valmis (voi kestää tunteja)
# Status muuttuu: scan: resilver completed
```

**TrueNAS Web-UI**: Storage → tank → Manage Devices → valitse hajonnut levy → Replace

### Resilvering-aika

| Datamäärä | Arvioitu aika (HDD) |
|-----------|---------------------|
| 500 GB | ~1-2 tuntia |
| 1 TB | ~2-4 tuntia |
| 2 TB | ~4-8 tuntia |

Pool toimii normaalisti resilveroinnin aikana, mutta hitaammin.

## Tilanne 2: Molemmat levyt hajonneet

Jos molemmat mirror-levyt ovat hajonneet, data on menetetty poolista. Palauta USB-backupista.

### Luo uusi pool

```bash
# Uudet levyt
zpool create tank mirror /dev/sdX /dev/sdY
```

### Palauta ZFS-snapshotista

```bash
# Mounttaa USB-levy
mount /dev/sdZ1 /mnt/usb-backup

# Palauta täysi snapshot
zfs receive -F tank/apps < /mnt/usb-backup/apps/full-YYYY-MM-DD_HH-MM.zfs

# Jos on inkrementaaleja, aja ne järjestyksessä täyden päälle
zfs receive -F tank/apps < /mnt/usb-backup/apps/incr-YYYY-MM-DD_HH-MM.zfs

# Toista jokaiselle datasetille
zfs receive -F tank/nextcloud < /mnt/usb-backup/nextcloud/full-YYYY-MM-DD_HH-MM.zfs
zfs receive -F tank/shared < /mnt/usb-backup/shared/full-YYYY-MM-DD_HH-MM.zfs
```

### Palauta palvelut

```bash
# Luo puuttuvat datasetit (media, downloads - ei backupoitu)
zfs create tank/media
zfs create tank/media/movies
zfs create tank/media/tv
zfs create tank/media/music
zfs create tank/downloads
zfs create tank/downloads/complete
zfs create tank/downloads/incomplete

# Aseta oikeudet
chown -R 568:568 /mnt/tank/apps /mnt/tank/media /mnt/tank/downloads /mnt/tank/nextcloud /mnt/tank/shared

# Käynnistä Docker
cd /mnt/tank/apps/compose
docker compose up -d
```

## Tilanne 3: Palauta yksittäinen tiedosto snapshotista

ZFS-snapshotit ovat piilotetussa `.zfs`-kansiossa:

```bash
# Listaa snapshotit
ls /mnt/tank/nextcloud/.zfs/snapshot/

# Kopioi tiedosto takaisin
cp /mnt/tank/nextcloud/.zfs/snapshot/backup-2024-01-15_03-00/important-file.txt \
   /mnt/tank/nextcloud/important-file.txt
```

## Tilanne 4: Rollback koko dataset edelliseen tilaan

```bash
# VAROITUS: Tämä poistaa kaikki muutokset snapshotin jälkeen!
zfs rollback tank/nextcloud@backup-2024-01-15_03-00
```

## Ennaltaehkäisy

### Scrub (levytarkistus) - aja kuukausittain
```bash
zpool scrub tank
# Seuraa: zpool status tank
```

TrueNAS ajaa scrub automaattisesti (Data Protection → Scrub Tasks).

### S.M.A.R.T. -monitorointi
TrueNAS valvoo levyjen terveyttä automaattisesti ja varoittaa ennen hajoamista.

**Data Protection → S.M.A.R.T. Tests → Add** → Short test viikoittain, Long test kuukausittain.

### Hälytykset
**System Settings → Alert Settings** → Aseta sähköpostihälytykset levyvirheistä.
