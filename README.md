# Kotipalvelin - TrueNAS SCALE

Kotipalvelin jossa *arr-stack NordVPN:n takana, Nextcloud, Jellyfin ja NAS.

## Arkkitehtuuri

```
┌──────────────────────────────────────────────────────┐
│  TrueNAS SCALE                                       │
│                                                      │
│  tank (2x 2TB stripe → 4TB käytettävä)               │
│    → apps, media, downloads, nextcloud, shared       │
│                                                      │
│  Jatkossa: media-pool (3x 8TB RAIDZ1 → 16TB)        │
│    → ks. expansion-guide.md                          │
│                                                      │
│  Docker Compose:                                     │
│  ┌──────────────────────────────────────────┐        │
│  │ gluetun (NordVPN/OpenVPN)                │        │
│  │  ├── qbittorrent      :8080              │        │
│  │  ├── prowlarr          :9696             │        │
│  │  ├── sonarr            :8989             │        │
│  │  ├── radarr            :7878             │        │
│  │  └── bazarr            :6767             │        │
│  ├── jellyfin             :8096             │        │
│  ├── nextcloud            :8443             │        │
│  │   ├── mariadb                            │        │
│  │  └── redis                               │        │
│  └── SMB (TrueNAS built-in)  :445           │        │
│  └──────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────┘
```

## Vaatimukset

- Kone jossa vähintään 8GB RAM (ZFS syö muistia)
- 2x 2TB HDD
- USB-tikku TrueNAS-asennukseen
- USB-levy / erillinen levy backupille
- NordVPN-tilaus

## Asennus

### 1. TrueNAS SCALE asennus

1. Lataa TrueNAS SCALE ISO: https://www.truenas.com/download-truenas-scale/
2. Kirjoita ISO USB-tikulle (esim. Rufus, Etcher tai `dd`)
3. Boottaa palvelin USB-tikulta ja asenna
   - Asennuslevy: erillinen SSD/USB (EI datalevy!)
   - Aseta root-salasana
4. Bootaa TrueNAS ja avaa web-UI: `http://<palvelimen-ip>`

### 2. ZFS Pool (2x 2TB Stripe)

Web-UI:ssa: **Storage → Create Pool**

1. Nimi: `tank`
2. Valitse molemmat 2TB levyt
3. Layout: **Stripe**
4. Luo pool

> **Huom**: Stripe EI tarjoa redundanssia - jos yksi levy hajoaa, kaikki
> data menetetään. Pidä USB-backupit ajan tasalla! Redundanssi tulee
> jatkossa media-pooliin (3x 8TB RAIDZ1), ks. [expansion-guide.md](expansion-guide.md).

### 3. Luo datasetit

Katso [datasets.md](datasets.md) tai shellissä:

```bash
zfs create tank/apps
zfs create tank/media
zfs create tank/media/movies
zfs create tank/media/tv
zfs create tank/media/music
zfs create tank/downloads
zfs create tank/downloads/complete
zfs create tank/downloads/incomplete
zfs create tank/nextcloud
zfs create tank/shared

zfs set atime=off tank
zfs set recordsize=1M tank/media
```

### 4. Docker Compose asennus

TrueNAS SCALE (Dragonfish+) tukee Docker Composea natiivisti. Kopioi tiedostot palvelimelle:

```bash
# Luo kansio Docker-configeille
mkdir -p /mnt/tank/apps/compose
cd /mnt/tank/apps/compose

# Kopioi tiedostot (esim. scp:llä omalta koneelta):
# scp docker-compose.yml .env root@<palvelin-ip>:/mnt/tank/apps/compose/

# Tai luo .env tiedosto .env.example pohjalta:
cp .env.example .env
nano .env  # Täytä oikeat arvot

# Käynnistä palvelut
docker compose up -d
```

### 5. SMB-jaot (NAS)

Katso [smb-shares.md](smb-shares.md) - konfiguroi TrueNAS Web-UI:sta.

### 6. Backup

Katso [backup/](backup/) - ZFS snapshot + send USB-levylle.

### 7. Levyjen lisääminen (3x 8TB RAIDZ1)

Katso [expansion-guide.md](expansion-guide.md).

## Palvelujen osoitteet

| Palvelu | Osoite | Oletus-tunnukset |
|---------|--------|-------------------|
| qBittorrent | http://palvelin:8080 | admin / adminadmin (vaihda heti!) |
| Prowlarr | http://palvelin:9696 | Aseta ensimmäisellä käynnistyksellä |
| Sonarr | http://palvelin:8989 | Aseta ensimmäisellä käynnistyksellä |
| Radarr | http://palvelin:7878 | Aseta ensimmäisellä käynnistyksellä |
| Bazarr | http://palvelin:6767 | Aseta ensimmäisellä käynnistyksellä |
| Jellyfin | http://palvelin:8096 | Aseta ensimmäisellä käynnistyksellä |
| Nextcloud | http://palvelin:8443 | .env tiedostossa |
| TrueNAS UI | http://palvelin | root / asennuksessa asetettu |

## Ensikonfigurointi palveluille

### qBittorrent

1. Kirjaudu sisään (admin/adminadmin) → vaihda salasana
2. Settings → Downloads → Default Save Path: `/data/downloads/complete`
3. Settings → Downloads → Incomplete: `/data/downloads/incomplete`

### Prowlarr

1. Lisää indexerit (torrent-sivustot)
2. Settings → Apps → Lisää Sonarr ja Radarr
   - Osoitteena käytä `localhost` koska kaikki ovat samassa verkossa (gluetun)

### Sonarr / Radarr

1. Settings → Media Management → Root Folders:
   - Sonarr: `/data/media/tv`
   - Radarr: `/data/media/movies`
2. Settings → Download Clients → Lisää qBittorrent
   - Host: `localhost`, Port: `8080`
3. Settings → Media Management → **Use Hardlinks instead of Copy**: ON

### Bazarr

1. Settings → Sonarr / Radarr → lisää yhteydet (localhost + API key)
2. Valitse kieliasetukset tekstityksille

### Jellyfin

1. Luo admin-käyttäjä
2. Lisää kirjastot:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
   - Music: `/media/music`

### VPN-tarkistus

Tarkista että VPN toimii:

```bash
docker exec gluetun wget -qO- https://ipinfo.io
# Pitäisi näyttää NordVPN:n IP, EI oma IP
```

## Hyödyllisiä komentoja

```bash
# Kaikkien konttien tila
docker compose ps

# Logit (seuraa reaaliaikaisesti)
docker compose logs -f gluetun
docker compose logs -f sonarr

# Käynnistä uudelleen
docker compose restart sonarr

# Päivitä kaikki imaget
docker compose pull && docker compose up -d

# ZFS-poolin tila
zpool status tank

# Levytilan käyttö
zfs list
```
