# SMB/NAS-jakojen konfigurointi

TrueNAS SCALE hallitsee SMB-jakoja Web-UI:sta. Ei tarvita Docker-konttia.

## 1. Luo SMB-käyttäjä

**Credentials → Local Users → Add**

- Username: `nas_user` (tai haluamasi)
- Password: vahva salasana
- Primary Group: `users`
- Home Directory: `/nonexistent`
- Shell: `nologin`
- Samba Authentication: **ON**

## 2. Aseta dataset-oikeudet

**Storage → tank/shared → Edit Permissions**

- User: `nas_user`
- Group: `users`
- ACL Type: POSIX (yksinkertaisin)
- Recursive: kyllä

## 3. Luo SMB-jako

**Shares → SMB → Add**

### Yleinen jako (kaikki tiedostot)

- Path: `/mnt/tank/shared`
- Name: `shared`
- Purpose: Default share
- Enabled: ON

### Media-jako (vain luku)

- Path: `/mnt/tank/media`
- Name: `media`
- Purpose: Default share
- Enabled: ON
- Advanced → Auxiliary Parameters:
  ```
  read only = yes
  ```

## 4. Käynnistä SMB-palvelu

**System Settings → Services → SMB → Running: ON, Start Automatically: ON**

## 5. Yhdistä jakoon

### Windows
```
\\palvelimen-ip\shared
\\palvelimen-ip\media
```
Tai Resurssienhallinnassa: Tämä tietokone → Yhdistä verkkoasema

### macOS
Finder → Go → Connect to Server:
```
smb://palvelimen-ip/shared
smb://palvelimen-ip/media
```

### Linux
```bash
# Väliaikainen mount
sudo mount -t cifs //palvelimen-ip/shared /mnt/nas -o username=nas_user

# Pysyvä (/etc/fstab)
//palvelimen-ip/shared  /mnt/nas  cifs  username=nas_user,password=salasana,uid=1000  0  0
```

## Suositellut jaot

| Jako | Polku | Käyttö | Oikeudet |
|------|-------|--------|----------|
| shared | /mnt/tank/shared | Yleinen tiedostonjako | Luku+kirjoitus |
| media | /mnt/tank/media | Elokuvat, sarjat, musiikki | Vain luku |
| nextcloud | /mnt/tank/nextcloud | Nextcloud-data (valinnainen) | Vain luku |
