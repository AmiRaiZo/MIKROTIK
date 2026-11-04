<div align="center">

**🇬🇧 English** | [🇮🇷 فارسی](README.fa.md)

# MikroTik Installer

**Install MikroTik RouterOS on your Linux server with one command.**
Docker installation with only Winbox TCP port `36666` exposed, and a `mik-help` shortcut to reopen the menu anytime.

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
1) CHR install (disabled; use Docker to expose only port 36666)
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
| **1** | Disabled. CHR uses the server network interface directly and cannot guarantee the single-port policy. |
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

No other TCP or UDP ports are published by Docker. SSH, WebFig, API, L2TP/IPsec, WireGuard and SSTP are not exposed on the server.

Option **4** recreates the container with the same single-port mapping. Existing RouterOS settings are lost, so export your configuration first with `/export file=backup`.

## After installation

The host port `36666` forwards to Winbox TCP `8291` inside RouterOS. No other host ports are published.

For ports with the same number on both sides (for example WireGuard `51820`), opening the port in Docker is not enough. The service must also listen on that port inside RouterOS.

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
- For CHR (option 1): **VNC/console access** from your hosting panel, in case the network needs manual setup after reboot

---

## Warnings

- **Option 1 (CHR) erases the entire disk.** Everything on the server is lost. Back up first, and confirm your hosting provider allows custom images.
- After CHR boots, the IP address comes from DHCP. If your provider does not use DHCP, set the IP from the VNC console.
- The free CHR license limits every interface to **1 Mbps**. Buy a license for real use.
- With Docker, only Winbox TCP port `36666` is published. Restrict access to it with your provider firewall if needed.
- Never leave the default password on a server that is reachable from the internet.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Container does not start | Another program is using one of your ports (for example 4433 or 2222). Free the port or choose another one. |
| Cannot connect over SSH after install | Your new MikroTik SSH port is `2222` (server port), not `22`. |
| L2TP/IPsec does not connect through Docker | Docker forwards only TCP and UDP ports, not the ESP protocol that IPsec uses. Make sure UDP 500, 4500 and 1701 are open in your provider's firewall. If it still fails, use another protocol such as WireGuard or SSTP. |
| `curl` gives a 404 error | The repository must be **Public**, and the file name must be `install.sh` on the `main` branch. |
| Ran out of RAM | Do not open thousands of ports. Every mapped port uses extra memory in Docker. |

---

## Uninstall

Open the menu with `mik-help` (or run the install command again) and choose **5) Uninstall All**.

---

## Credits

Based on [Ptechgithub/MIKROTIK](https://github.com/Ptechgithub/MIKROTIK). This version exposes only Winbox TCP port `36666`, includes the `mik-help` shortcut, and supports full uninstall.

MikroTik and RouterOS are trademarks of MikroTik. This project is not affiliated with MikroTik.

If this project helped you, a star on the repository is appreciated.
