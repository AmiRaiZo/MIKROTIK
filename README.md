<div align="center">

**🇬🇧 English** | [🇮🇷 فارسی](README.fa.md)

# MikroTik Installer

**Install MikroTik RouterOS on your Linux server with one command.**
Docker installation publishes only Winbox TCP port `36666`; CHR installation is also available as a separate, destructive bare-metal option. A `mik-help` shortcut reopens the menu anytime.

![Ubuntu](https://img.shields.io/badge/Ubuntu-supported-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-supported-A81D33?style=flat-square&logo=debian&logoColor=white)
![CentOS](https://img.shields.io/badge/CentOS-supported-262577?style=flat-square&logo=centos&logoColor=white)
![Fedora](https://img.shields.io/badge/Fedora-supported-51A2DA?style=flat-square&logo=fedora&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-100%25-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![Stars](https://img.shields.io/github/stars/AmiRaiZo/MIKROTIK?style=flat-square)

</div>

---

## Quick Install

Run this on your server as **root** (or a user with `sudo`):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmiRaiZo/MIKROTIK/main/install.sh)
```

After the first run, you can open the menu again from anywhere in SSH with:

```bash
mik-help
```

> Use the `bash <(curl ...)` form exactly as written. `curl ... | bash` will not work because the installer asks you questions.

---

## Default Logins

| Version | Username | Password |
|---|---|---|
| Docker | `admin` | `admin` |
| CHR | `admin` | ❌ |

> ❌ means the password is empty.

**Change the password right after the first login.** Inside the MikroTik console:

```
/user set admin password=YOUR_STRONG_PASSWORD
```

**Docker install:** to log in with Winbox, use port **`36666`** (`SERVER_IP:36666`).

---

## Menu

```
-------MikroTik Installer-------
Select an option:
1) Install MikroTik CHR (destructive: replaces the server OS/disk)
----------------------------
2) Install MikroTik via Docker
3) Uninstall MikroTik via Docker
4) Recreate Docker container (Winbox port only)
5) Uninstall All
----------------------------
0) Exit
```

| Option | What it does |
|:---:|---|
| **1** | Downloads and installs MikroTik CHR by replacing the server's entire disk/OS. This is destructive and uses the host network directly; port filtering must be configured in the provider firewall and/or RouterOS. |
| **2** | Installs Docker (if missing) and runs MikroTik with only host TCP port `36666` forwarded to Winbox (`8291/tcp`). |
| **3** | Removes the MikroTik container and its Docker image. |
| **4** | Deletes the container and recreates it with only TCP port `36666` forwarded to Winbox. |
| **5** | Removes everything: container, image, downloaded files and the `mik-help` command. Docker itself is kept. |

---

## Docker install: exposed port

The installer publishes exactly one host port:

| Service | Host port | Container port |
|---|---:|---:|
| Winbox | TCP `36666` | TCP `8291` |

This single-port rule applies to the Docker installation only. CHR uses the host network directly, so its reachable services depend on RouterOS firewall rules and the hosting provider's network firewall.

Option **4** recreates the container with the same single-port mapping. Existing RouterOS settings are lost, so export your configuration first with `/export file=backup`.

## After installation

**Docker:** host TCP port `36666` forwards to Winbox TCP `8291` inside RouterOS. No other host ports are published by Docker.

**CHR:** the installer replaces the server's entire disk with the CHR image. Make sure you have provider console/VNC access and a backup before proceeding. CHR uses the server network directly.

**Leave the Docker console** without stopping the container: press `Ctrl+P` then `Ctrl+Q`.
**Reconnect to it later:**

```bash
docker attach livekadeh_com_mikrotik7_7
```

---

## Requirements

- A VPS or server running **Ubuntu, Debian, CentOS or Fedora**
- Root access or `sudo`
- Internet access from the server
- At least **1 GB RAM** and **1 CPU core** is enough for the Docker version

---

## Warnings

- With Docker, only Winbox TCP port `36666` is published.
- CHR installation erases the server disk and replaces its operating system. Back up first and ensure provider console/VNC access.
- CHR does not use Docker port mapping; secure its services with RouterOS firewall rules and the provider firewall.
- Never leave the default password on a server that is reachable from the internet.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Container does not start | Another program is already using host TCP port `36666`. Free that port before installing. |
| `curl` gives a 404 error | The repository must be **Public**, and the file name must be `install.sh` on the `main` branch. |

---

## Uninstall

Open the menu with `mik-help` (or run the install command again) and choose **5) Uninstall All**.

---

## Credits

Based on [Ptechgithub/MIKROTIK](https://github.com/Ptechgithub/MIKROTIK). This version exposes only Winbox TCP port `36666`, includes the `mik-help` shortcut, and supports full uninstall.

MikroTik and RouterOS are trademarks of MikroTik. This project is not affiliated with MikroTik.

If this project helped you, a star on the repository is appreciated.
