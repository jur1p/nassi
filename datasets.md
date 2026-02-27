# ZFS Dataset -rakenne

## Pool: tank (Mirror 2x 2TB)

```
tank/                          ← Pool root
├── tank/apps                  ← Docker-konttien konfiguraatiot
├── tank/media                 ← Mediatiedostot
│   ├── tank/media/movies      ← Elokuvat (Radarr → Jellyfin)
│   ├── tank/media/tv          ← TV-sarjat (Sonarr → Jellyfin)
│   └── tank/media/music       ← Musiikki
├── tank/downloads             ← Lataukset
│   ├── tank/downloads/complete    ← Valmiit
│   └── tank/downloads/incomplete  ← Keskeneräiset
├── tank/nextcloud             ← Nextcloud käyttäjädata
└── tank/shared                ← Yleinen NAS-jako (SMB)
```

## Luonti Web-UI:sta

**Storage → tank → Add Dataset** jokaista kohtaa varten.

Suositellut asetukset:
- **Compression**: lz4 (oletus, hyvä)
- **Atime**: off (parempi suorituskyky)
- **Record Size**:
  - `tank/media`: 1M (suuret tiedostot)
  - `tank/apps`: 128K (oletus)
  - `tank/nextcloud`: 128K (oletus)

## Luonti shellissä

```bash
# Perusdatasetit
zfs create tank/apps
zfs create tank/media
zfs create tank/downloads
zfs create tank/nextcloud
zfs create tank/shared

# Alidatasetit
zfs create tank/media/movies
zfs create tank/media/tv
zfs create tank/media/music
zfs create tank/downloads/complete
zfs create tank/downloads/incomplete

# Optimoinnit
zfs set atime=off tank
zfs set recordsize=1M tank/media
```

## Oikeudet

Docker-kontit käyttävät PUID/PGID-arvoja (oletuksena 568 TrueNAS:ssa). Varmista oikeudet:

```bash
chown -R 568:568 /mnt/tank/apps
chown -R 568:568 /mnt/tank/media
chown -R 568:568 /mnt/tank/downloads
chown -R 568:568 /mnt/tank/nextcloud
chown -R 568:568 /mnt/tank/shared
```

## Miksi erilliset datasetit?

- **Snapshottaus**: Voit ottaa snapshotin vain kriittisestä datasta (nextcloud) ilman media-dataa
- **Kompressio**: Eri asetukset eri datatyypeille
- **Quotat**: Voit rajoittaa downloads-kansion kokoa ettei se syö kaikkea tilaa
- **Monitorointi**: `zfs list` näyttää kunkin datasetin käytön erikseen
