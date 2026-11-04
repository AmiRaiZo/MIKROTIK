<div align="center">

[🇬🇧 English](README.md) | **🇮🇷 فارسی**

# نصب‌کننده‌ی میکروتیک

**نصب میکروتیک RouterOS روی سرور لینوکس با یک دستور.**
نصب با Docker با باز بودن فقط پورت TCP شماره‌ی `36666` برای Winbox، و دستور کوتاه `mik-help` برای باز کردن دوباره‌ی منو در هر زمان.

![Ubuntu](https://img.shields.io/badge/Ubuntu-supported-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-supported-A81D33?style=flat-square&logo=debian&logoColor=white)
![CentOS](https://img.shields.io/badge/CentOS-supported-262577?style=flat-square&logo=centos&logoColor=white)
![Fedora](https://img.shields.io/badge/Fedora-supported-51A2DA?style=flat-square&logo=fedora&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-100%25-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![Stars](https://img.shields.io/github/stars/AmiRaiZo/MIKROTIK?style=flat-square)

</div>

---

<div dir="rtl" align="right">

## نصب سریع

این دستور را روی سرور با کاربر **root** (یا کاربری که `sudo` دارد) اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/AmiRaiZo/MIKROTIK/main/install.sh)
```

بعد از اولین اجرا، از هر جای SSH می‌توانید منو را دوباره باز کنید:

```bash
mik-help
```

> دستور را دقیقاً به شکل `bash <(curl ...)` اجرا کنید. اجرای `curl ... | bash` کار نمی‌کند، چون نصب‌کننده از شما سؤال می‌پرسد.

---

## مشخصات ورود پیش‌فرض

| نسخه | نام کاربری | رمز عبور |
|---|---|---|
| Docker | `admin` | `admin` |
| CHR | `admin` | ❌ |

> علامت ❌ یعنی رمز عبور خالی است.

**بعد از اولین ورود، رمز عبور را عوض کنید.** داخل کنسول میکروتیک:

```
/user set admin password=YOUR_STRONG_PASSWORD
```

**نصب با Docker:** برای ورود با Winbox از پورت **`36666`** استفاده کنید (`SERVER_IP:36666`).

---

## منو

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

| گزینه | کاربرد |
|:---:|---|
| **1** | غیرفعال است؛ CHR مستقیماً از کارت شبکه‌ی سرور استفاده می‌کند و محدودیت تک‌پورت را تضمین نمی‌کند. |
| **2** | Docker را نصب می‌کند و میکروتیک را طوری اجرا می‌کند که فقط پورت TCP شماره‌ی `36666` به Winbox داخل کانتینر (`8291/tcp`) وصل باشد. |
| **3** | کانتینر میکروتیک و ایمیج Docker آن را حذف می‌کند. |
| **4** | کانتینر را پاک می‌کند و یکی جدید با تنها پورت TCP شماره‌ی `36666` می‌سازد. |
| **5** | همه‌چیز را پاک می‌کند: کانتینر، ایمیج، فایل‌های دانلودشده و دستور `mik-help`. خود Docker باقی می‌ماند. |

---

## پورت باز در نصب Docker

نصب‌کننده فقط همین یک پورت را روی سرور منتشر می‌کند:

| سرویس | پورت سرور | پورت داخل کانتینر |
|---|---:|---:|
| Winbox | TCP `36666` | TCP `8291` |

هیچ پورت TCP یا UDP دیگری توسط Docker روی سرور منتشر نمی‌شود. SSH، WebFig، API، L2TP/IPsec، WireGuard و SSTP از بیرون سرور در دسترس نخواهند بود.

گزینه‌ی **4** کانتینر را با همین تنظیم تک‌پورت دوباره می‌سازد. تنظیمات قبلی RouterOS پاک می‌شود؛ پس قبلش دستور `/export file=backup` را اجرا کنید.

## بعد از نصب

پورت سرور `36666` به Winbox با TCP `8291` داخل RouterOS وصل می‌شود. هیچ پورت دیگری روی سرور منتشر نمی‌شود.

**خروج از کنسول Docker** بدون متوقف کردن کانتینر: کلید `Ctrl+P` و بعد `Ctrl+Q` را بزنید.
**برگشت دوباره به کنسول:**

```bash
docker attach livekadeh_com_mikrotik7_7
```

---

## پیش‌نیازها

- یک VPS یا سرور با **Ubuntu، Debian، CentOS یا Fedora**
- دسترسی root یا `sudo`
- اینترنت روی سرور
- برای نسخه‌ی Docker حداقل **1 گیگابایت رم** و **1 هسته‌ی CPU** کافی است

---

## هشدارها

- در نصب با Docker فقط پورت TCP شماره‌ی `36666` برای Winbox منتشر می‌شود. در صورت نیاز دسترسی به آن را از فایروال ارائه‌دهنده محدود کنید.
- هرگز رمز عبور پیش‌فرض را روی سروری که از اینترنت در دسترس است نگه ندارید.

---

## عیب‌یابی

| مشکل | راه‌حل |
|---|---|
| کانتینر بالا نمی‌آید | برنامه‌ی دیگری از پورت TCP شماره‌ی `36666` استفاده می‌کند. قبل از نصب آن پورت را آزاد کنید. |
| `curl` خطای 404 می‌دهد | ریپو باید **Public** باشد و اسم فایل روی شاخه‌ی `main` دقیقاً `install.sh` باشد. |

---

## حذف

منو را با `mik-help` باز کنید (یا دستور نصب را دوباره اجرا کنید) و گزینه‌ی **5) Uninstall All** را بزنید.

---

## منبع

بر پایه‌ی [Ptechgithub/MIKROTIK](https://github.com/Ptechgithub/MIKROTIK). این نسخه فقط پورت TCP شماره‌ی `36666` برای Winbox را منتشر می‌کند و دستور `mik-help` و حذف کامل را دارد.

MikroTik و RouterOS علائم تجاری شرکت MikroTik هستند. این پروژه وابسته به MikroTik نیست.

اگر این پروژه به شما کمک کرد، ستاره (Star) دادن به ریپو باعث خوشحالی است.

</div>
