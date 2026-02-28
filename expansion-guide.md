# Levyjen lisääminen: 3x 8TB RAIDZ1

## Nykytilanne

```
tank (stripe, 2x 2TB)
  disk1: 2TB
  disk2: 2TB
  → 4TB käytettävissä, EI redundanssia
  → kaikki data (apps, media, downloads, nextcloud, shared)
```

## Tavoite: media-pool (3x 8TB RAIDZ1)

Lisää 3x 8TB levyä → erillinen `media`-pool medialle ja latauksille.
RAIDZ1 = 1 levy voi hajota ilman datan menetystä, 16TB käytettävissä.

```
Jälkeen:
  tank  (2x 2TB stripe)  → 4TB  → apps, nextcloud, shared
  media (3x 8TB RAIDZ1)  → 16TB → downloads, media
```

## Vaihe 1: Luo media-pool

### Web-UI:sta

**Storage → Create Pool**

1. Nimi: `media`
2. Valitse kaikki 3x 8TB levyt
3. Layout: **RAIDZ1**
4. Luo pool

### Shellissä

```bash
# Tarkista levyjen nimet
lsblk

# Luo RAIDZ1 pool
zpool create media raidz1 /dev/sdX /dev/sdY /dev/sdZ

# Luo datasetit
zfs create media/downloads
zfs create media/downloads/complete
zfs create media/downloads/incomplete
zfs create media/media
zfs create media/media/movies
zfs create media/media/tv
zfs create media/media/music

# Optimoinnit
zfs set atime=off media
zfs set recordsize=1M media/media

# Oikeudet
chown -R 568:568 /mnt/media/downloads /mnt/media/media
```

## Vaihe 2: Siirrä data tankista mediaan

```bash
# Siirrä media-tiedostot
rsync -avP /mnt/tank/media/ /mnt/media/media/
rsync -avP /mnt/tank/downloads/ /mnt/media/downloads/

# Tarkista että kaikki siirtyi
ls -la /mnt/media/media/movies/
ls -la /mnt/media/downloads/

# Poista vanhat (vasta kun olet varma!)
rm -rf /mnt/tank/media/movies/* /mnt/tank/media/tv/* /mnt/tank/media/music/*
rm -rf /mnt/tank/downloads/complete/* /mnt/tank/downloads/incomplete/*
```

## Vaihe 3: Päivitä docker-compose.yml

Vaihda volume-mountit:

```yaml
# qbittorrent, sonarr, radarr, bazarr - vaihda:
volumes:
  - /mnt/tank/apps/[kontti]:/config
  - /mnt/media:/data                    # ← tank → media

# jellyfin - vaihda:
volumes:
  - /mnt/tank/apps/jellyfin:/config
  - /mnt/media/media:/media             # ← tank → media
```

Käynnistä uudelleen:

```bash
cd /mnt/tank/apps/compose
docker compose down && docker compose up -d
```

## Vaihe 4: Päivitä palveluasetukset

Konttien sisäiset polut (`/data/...`, `/media/...`) eivät muutu koska
mount-kohde on sama. Tarkista kuitenkin:

- qBittorrent: `/data/downloads/complete` ja `/data/downloads/incomplete`
- Sonarr: `/data/media/tv`
- Radarr: `/data/media/movies`
- Jellyfin: `/media/movies`, `/media/tv`, `/media/music`

## Hajotetun levyn vaihto (media-pool)

```bash
# 1. Tarkista mikä levy on hajonnut
zpool status media

# 2. Vaihda fyysinen levy ja korvaa
zpool replace media /dev/old_disk /dev/new_disk

# 3. Seuraa resilveroinnin edistymistä
zpool status media
```

**TrueNAS Web-UI**: Storage → media → Manage Devices → valitse hajonnut → Replace

## Media-poolin laajentaminen jatkossa

### Vaihtoehto A: Korvaa levyt isommilla (yksi kerrallaan)

```bash
zpool replace media /dev/old1 /dev/new1
# odota resilvering...
zpool replace media /dev/old2 /dev/new2
# odota resilvering...
zpool replace media /dev/old3 /dev/new3

zpool set autoexpand=on media
```

### Vaihtoehto B: Lisää toinen RAIDZ1-vdev

```bash
# 3x uutta levyä toisena vdev:nä
zpool add media raidz1 /dev/sdA /dev/sdB /dev/sdC
# Tulos: 2x RAIDZ1 = 32TB käytettävissä
```

## Kapasiteettitaulukko

| Kokoonpano | Raakaa | Käytettävissä | Levyjä voi hajota |
|---|---|---|---|
| 3x 8TB RAIDZ1 | 24TB | **16TB** | 1 |
| 4x 8TB RAIDZ1 | 32TB | 24TB | 1 |
| 4x 8TB RAIDZ2 | 32TB | 16TB | 2 |
| 6x 8TB RAIDZ1 (2 vdev) | 48TB | 32TB | 1 per vdev |
