# Levyjen lisääminen jatkossa

## Nykytilanne

```
tank (mirror)
  disk1: 2TB
  disk2: 2TB
  → 2TB käytettävissä, 1 levy voi hajota
```

## Vaihtoehto 1: Uusi mirror-pari (suositeltu)

Osta 2x samankokoista levyä (esim. 2x 8TB) ja lisää uusi vdev pooliin.

```bash
# Tarkista levyjen nimet
lsblk

# Lisää uusi mirror-pari pooliin
zpool add tank mirror /dev/sdX /dev/sdY

# Tulos:
# tank
#   mirror-0 (2TB)
#     sda
#     sdb
#   mirror-1 (8TB)    ← UUSI
#     sdX
#     sdY
#   → Yhteensä 10TB käytettävissä
```

**TrueNAS Web-UI**: Storage → tank → Manage Devices → Add VDEV → Mirror

Edut:
- Pool kasvaa välittömästi
- Kaikki datasetit näkevät uuden tilan automaattisesti
- Kummastakin mirror-parista yksi levy voi hajota

## Vaihtoehto 2: Erillinen pool

Jos haluat pitää median ja kriittisen datan erillään:

```bash
# Luo uusi pool
zpool create media mirror /dev/sdX /dev/sdY

# Luo datasetit
zfs create media/movies
zfs create media/tv
zfs create media/music
```

Tällöin docker-compose.yml:n volume-polut pitää päivittää:
```yaml
# Ennen:
- /mnt/tank/media/movies:/movies
# Jälkeen:
- /mnt/media/movies:/movies
```

## Vaihtoehto 3: RAIDZ1 (3+ levyä)

Jos ostat 3 levyä kerralla, RAIDZ1 antaa enemmän tilaa:

```bash
# 3x 8TB → 16TB käytettävissä (1 levy voi hajota)
zpool create media raidz1 /dev/sdX /dev/sdY /dev/sdZ
```

| Kokoonpano | Raakaa | Käytettävissä | Levyjä voi hajota |
|---|---|---|---|
| 3x 8TB mirror | - | ei mahdollinen | - |
| 3x 8TB RAIDZ1 | 24TB | 16TB | 1 |
| 4x 8TB RAIDZ1 | 32TB | 24TB | 1 |
| 4x 8TB RAIDZ2 | 32TB | 16TB | 2 |

## Vanhojen 2TB levyjen korvaaminen isommilla

Jos haluat korvata alkuperäiset 2TB levyt isommilla:

```bash
# 1. Korvaa ensimmäinen levy
zpool replace tank /dev/old_disk1 /dev/new_disk1
# Odota resilvering (tunteja - riippuu datamäärästä)
zpool status tank  # seuraa edistymistä

# 2. Kun resilvering valmis, korvaa toinen
zpool replace tank /dev/old_disk2 /dev/new_disk2
# Odota taas resilvering

# 3. Pool kasvaa automaattisesti kun molemmat on vaihdettu
zpool set autoexpand=on tank
zpool online -e tank /dev/new_disk1
zpool online -e tank /dev/new_disk2
```

## Suositus laajennuspoluksi

```
Nyt:     2x 2TB mirror                    =  2TB
Vaihe 1: + 2x 8TB mirror (uusi vdev)      = 10TB
Vaihe 2: + 2x 8TB mirror (kolmas vdev)    = 18TB
  tai    + 3x 8TB RAIDZ1 (erillinen pool) = 18TB + 16TB
```
