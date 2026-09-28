<div align="center">

# MikroTik Installer

**Install MikroTik RouterOS on your Linux server with one command.**
Docker or CHR, custom TCP/UDP ports, and a `mik-help` shortcut to reopen the menu anytime.

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
1) Install MikroTik CHR (ERASES the whole disk!)
----------------------------
2) Install MikroTik via Docker
3) Uninstall MikroTik via Docker
4) Recreate Docker container with new ports
5) Uninstall All
----------------------------
0) Exit
```

| Option | What it does |
|:---:|---|
| **1** | Replaces the whole operating system with **MikroTik CHR**. The latest stable version is downloaded automatically from the official MikroTik server. |
| **2** | Installs Docker (if missing) and runs MikroTik in a container with the ports you choose. |
| **3** | Removes the MikroTik container and its Docker image. |
| **4** | Deletes the container and creates a new one with a new port list. |
| **5** | Removes everything: container, image, downloaded files and the `mik-help` command. Docker itself is kept. |

---

## Docker install: choosing ports

When the installer asks for ports, press **Enter** to use the defaults, or type your own comma-separated list.

**Default ports**

| Service | Port |
|---|---|
| L2TP/IPsec | `500/udp`, `4500/udp`, `1701/udp` |
| WireGuard | `51820/udp`, `48546/udp` |
| SSTP | `443/tcp` |
| Winbox | `36666` |
| SSH | `2222` (forwards to port `22` inside MikroTik) |

**Port format**

| You type | Meaning |
|---|---|
| `443` | TCP port 443 (TCP is the default) |
| `51820/udp` | UDP port 51820 |
| `2222:22/tcp` | Server port 2222 goes to port 22 in the container |
| `36666:8291/tcp` | Server port 36666 goes to Winbox inside the container |
| `1000-1100/udp` | A range of UDP ports |

Example:

```
500/udp,4500/udp,51820/udp,443/tcp,36666:8291/tcp,2222:22/tcp
```

> **Important:** Docker cannot add ports to an existing container. Option **4** deletes the old container and creates a new one, so you must enter the **full** port list again, and all RouterOS settings are lost. Run `/export file=backup` inside MikroTik first.

---

## After installation

For other services (WireGuard, L2TP, SSTP, ...), opening a port in Docker is not enough. The service must also listen on the same port inside RouterOS.

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
- With Docker, Winbox is reachable only through port `36666`. Remove it from the port list if you do not want Winbox exposed to the internet.
- Never leave the default password on a server that is reachable from the internet.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Container does not start | Another program is using one of your ports (for example 443 or 2222). Free the port or choose another one. |
| Cannot connect over SSH after install | Your new MikroTik SSH port is `2222` (server port), not `22`. |
| L2TP/IPsec does not connect through Docker | Docker only forwards UDP. If it fails, try again after checking UDP 500, 4500 and 1701 are open in your provider's firewall. |
| `curl` gives a 404 error | The repository must be **Public**, and the file name must be `install.sh` on the `main` branch. |
| Ran out of RAM | Do not open thousands of ports. Every mapped port uses extra memory in Docker. |

---

## Uninstall

Open the menu with `mik-help` (or run the install command again) and choose **5) Uninstall All**.

---

<div dir="rtl" align="right">

## راهنمای فارسی

این پروژه نصب **میکروتیک** روی سرور لینوکس را با یک دستور انجام می‌دهد. می‌توانید میکروتیک را با **Docker** یا به شکل **CHR** نصب کنید و پورت‌های TCP و UDP دلخواه را باز کنید.

**نصب:**

</div>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmiRaiZo/MIKROTIK/main/install.sh)
```

<div dir="rtl" align="right">

- بعد از اولین اجرا، در هر جای SSH فقط بنویسید `mik-help` تا منو دوباره باز شود.
- گزینه‌ی **1** (CHR) کل دیسک سرور را پاک می‌کند. حتماً قبلش بکاپ بگیرید و به کنسول VNC هاستینگ دسترسی داشته باشید.
- گزینه‌ی **4** کانتینر را از نو می‌سازد، پس باید همه‌ی پورت‌ها را دوباره وارد کنید و تنظیمات میکروتیک پاک می‌شود. قبلش دستور `/export file=backup` را بزنید.
- بعد از نصب، پسورد پیش‌فرض را فوراً عوض کنید.
- در نصب با Docker، برای ورود با وینباکس از پورت `36666` استفاده کنید.
- پورت SSH میکروتیک از بیرون `2222` است.

</div>

---

## Credits

Based on [Ptechgithub/MIKROTIK](https://github.com/Ptechgithub/MIKROTIK). This version adds a custom TCP/UDP port list, automatic latest CHR download, the `mik-help` shortcut, and full uninstall.

MikroTik and RouterOS are trademarks of MikroTik. This project is not affiliated with MikroTik.

If this project helped you, a star on the repository is appreciated.
