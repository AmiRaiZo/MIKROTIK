#!/bin/bash
# MikroTik (Docker) installer - modified version
# Based on Ptechgithub/MIKROTIK install.sh
#
# Changes:
#  - Accepts a list of ports (comma separated), with TCP/UDP per port
#  - Supports host:container mapping (e.g. 2222:22/tcp)
#  - Supports ranges (e.g. 1000-1100/udp)
#  - Ports 80 and 8291 are NOT opened unless you list them
#  - Option to recreate the container with a new port list
#  - CHR (dd) install option kept, with a YES confirmation and safer disk detection
#  - Removed the resolv.conf overwrite

CONTAINER="livekadeh_com_mikrotik7_7"
IMAGE_ARCHIVE="Docker-image-Mikrotik-7.7-L6.7z"
IMAGE_FILE="mikrotik7.7_docker_livekadeh.com"
# Docker image is downloaded from YOUR GitHub release (tag v1)
IMAGE_URL="https://github.com/AmiRaiZo/MIKROTIK/releases/download/v1/${IMAGE_ARCHIVE}"
# CHR: the latest stable version is fetched from mikrotik.com automatically;
# this version is only used if that lookup fails
CHR_FALLBACK_VERSION="7.15.2"

# Shortcut: after the first run, typing "mik-help" in SSH opens this menu again
SCRIPT_URL="https://raw.githubusercontent.com/AmiRaiZo/MIKROTIK/main/install.sh"
SHORTCUT_BIN="/usr/local/bin/mik-help"
SHORTCUT_CACHE="/usr/local/share/mik-help.sh"

# Default ports (press Enter to use them):
#   L2TP/IPsec : 500/udp 4500/udp 1701/udp
#   WireGuard  : 51820/udp 48546/udp
#   SSTP       : 443/tcp
#   Winbox     : 35300/tcp 36666/tcp
#   SSH        : host 2222 -> container 22
DEFAULT_PORTS="500/udp,4500/udp,1701/udp,51820/udp,48546/udp,443/tcp,35300/tcp,36666/tcp,2222:22/tcp"

SUDO=""
[ "$EUID" -ne 0 ] && SUDO="sudo"

detect_distribution() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "${ID}" in
            ubuntu|debian) PM="apt-get"; PKG7Z="p7zip-full" ;;
            centos)        PM="yum";     PKG7Z="p7zip p7zip-plugins" ;;
            fedora)        PM="dnf";     PKG7Z="p7zip p7zip-plugins" ;;
            *) echo "Unsupported distribution!"; exit 1 ;;
        esac
    else
        echo "Unsupported distribution!"
        exit 1
    fi
}

install_cmd() {
    # $1 = command to check, rest = packages to install
    local cmd="$1"; shift
    if ! command -v "$cmd" &> /dev/null; then
        echo "$cmd is not installed. Installing..."
        $SUDO $PM update -y
        $SUDO $PM install -y "$@"
    fi
}

check_dependencies() {
    detect_distribution
    install_cmd wget wget
    install_cmd curl curl
    install_cmd unzip unzip
    install_cmd 7z $PKG7Z
}

check_and_install_docker() {
    check_dependencies
    if ! command -v docker &> /dev/null; then
        echo "Installing docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        $SUDO sh get-docker.sh
        $SUDO systemctl start docker
        $SUDO systemctl enable docker
    else
        echo "Docker is already installed."
    fi
}

load_image() {
    if docker image inspect "$CONTAINER" &> /dev/null; then
        echo "Docker image already loaded."
        return 0
    fi
    [ -f "$IMAGE_ARCHIVE" ] || wget "$IMAGE_URL" || return 1
    7z e -y "$IMAGE_ARCHIVE" || return 1
    docker load --input "$IMAGE_FILE" || return 1
}

# Converts "500/udp,51820/udp,443,2222:22/tcp,1000-1100/udp" into PORT_ARGS array
build_port_args() {
    PORT_ARGS=()
    local input="${1// /}"
    local items item spec proto map
    IFS=',' read -ra items <<< "$input"
    for item in "${items[@]}"; do
        [ -z "$item" ] && continue
        spec="$item"
        proto="tcp"
        if [[ "$item" == */* ]]; then
            spec="${item%%/*}"
            proto="${item##*/}"
        fi
        proto="${proto,,}"
        if [[ "$proto" != "tcp" && "$proto" != "udp" ]]; then
            echo "Invalid protocol in '$item' (use tcp or udp)"
            return 1
        fi
        if [[ "$spec" =~ ^[0-9]+$ ]]; then
            map="$spec:$spec"
        elif [[ "$spec" =~ ^[0-9]+:[0-9]+$ ]]; then
            map="$spec"
        elif [[ "$spec" =~ ^[0-9]+-[0-9]+$ ]]; then
            map="$spec:$spec"
        else
            echo "Invalid port entry: '$item'"
            return 1
        fi
        PORT_ARGS+=("-p" "$map/$proto")
    done
    if [ "${#PORT_ARGS[@]}" -eq 0 ]; then
        echo "No ports given."
        return 1
    fi
}

ask_ports() {
    echo ""
    echo "Enter ports separated by comma. Format:  PORT[/tcp|/udp]  or  HOST:CONTAINER[/proto]  or  START-END[/proto]"
    echo "If no protocol is given, TCP is used."
    echo "Default: $DEFAULT_PORTS"
    read -p "Ports (press Enter for default): " user_ports
    user_ports="${user_ports:-$DEFAULT_PORTS}"
    build_port_args "$user_ports"
}

run_container() {
    echo "Starting container with: ${PORT_ARGS[*]}"
    docker run --restart unless-stopped --cap-add=NET_ADMIN --device=/dev/net/tun -d \
        --name "$CONTAINER" "${PORT_ARGS[@]}" -ti "$CONTAINER" || return 1
    echo ""
    echo "Container started. Attaching to console (detach with Ctrl+P then Ctrl+Q)..."
    docker attach "$CONTAINER"
}

install_mikrotik() {
    check_and_install_docker
    if docker ps -a --format "{{.Names}}" | grep -qx "$CONTAINER"; then
        echo "MikroTik container already exists. Use option 4 to recreate it with new ports."
        return 0
    fi
    load_image || { echo "Failed to load image."; exit 1; }
    ask_ports || exit 1
    run_container
}

recreate_mikrotik() {
    check_and_install_docker
    if ! docker image inspect "$CONTAINER" &> /dev/null; then
        load_image || { echo "Failed to load image."; exit 1; }
    fi

    echo ""
    echo "=============================================================="
    echo " WARNING: the current container will be DELETED."
    echo " - ALL previous ports will be removed. Only the ports you enter"
    echo "   now will be open, so enter the full list again."
    echo " - ALL RouterOS settings (users, WireGuard, firewall, ...) will"
    echo "   be lost. Export first inside MikroTik: /export file=backup"
    echo "=============================================================="
    if docker ps -a --format "{{.Names}}" | grep -qx "$CONTAINER"; then
        echo ""
        echo "Current port mappings:"
        docker port "$CONTAINER" 2>/dev/null || echo "(none)"
    fi

    ask_ports || exit 1
    read -p "Type YES to delete the old container and create a new one: " confirm
    [ "$confirm" == "YES" ] || { echo "Cancelled."; exit 0; }
    docker rm -f "$CONTAINER" 2>/dev/null
    run_container
}

uninstall_mikrotik() {
    if docker ps -a --format "{{.Names}}" | grep -qx "$CONTAINER"; then
        docker stop "$CONTAINER"
        docker rm "$CONTAINER"
        echo "MikroTik container has been stopped and removed."
    else
        echo "MikroTik container is not found."
    fi
    if docker image inspect "$CONTAINER" &> /dev/null; then
        docker rmi "$CONTAINER"
        echo "MikroTik Docker image has been removed."
    else
        echo "MikroTik Docker image is not found."
    fi
}

# Finds the latest stable RouterOS version from MikroTik's official servers.
# Prints the version (e.g. 7.20.1) and only accepts it if the CHR image exists.
get_latest_chr_version() {
    local url v
    for url in \
        "https://upgrade.mikrotik.com/routeros/NEWESTa7.stable" \
        "https://upgrade.mikrotik.com/routeros/NEWEST7.stable"; do
        v=$(curl -fsSL --max-time 15 "$url" 2>/dev/null | tr -d '\r' | head -n1 | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?')
        if [ -n "$v" ] && wget -q --spider "https://download.mikrotik.com/routeros/${v}/chr-${v}.img.zip"; then
            echo "$v"
            return 0
        fi
    done
    return 1
}

# Replaces the WHOLE OS/disk with MikroTik CHR (destructive!)
install_chr_image() {
    check_dependencies

    echo "Checking latest stable RouterOS version..."
    CHR_VERSION=$(get_latest_chr_version) || {
        CHR_VERSION="$CHR_FALLBACK_VERSION"
        echo "Could not detect the latest version, using fallback: $CHR_VERSION"
    }
    echo "CHR version: $CHR_VERSION"

    local root_src disk
    root_src=$(findmnt -no SOURCE /)
    disk=$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -n1)
    if [ -n "$disk" ]; then
        disk="/dev/$disk"
    else
        disk="$root_src"
    fi

    echo ""
    echo "WARNING: this will ERASE the entire disk ($disk) and replace the"
    echo "operating system with MikroTik CHR ${CHR_VERSION}. All data will be lost."
    echo "Make sure you have VNC/console access in your hosting panel and a backup."
    read -p "Type YES (capital letters) to continue: " confirm
    [ "$confirm" == "YES" ] || { echo "Cancelled."; return 0; }

    $SUDO wget "https://download.mikrotik.com/routeros/${CHR_VERSION}/chr-${CHR_VERSION}.img.zip" -O chr.img.zip \
        || { echo "Download failed."; return 1; }
    unzip -o chr.img.zip -d chr.img || { echo "Unzip failed."; return 1; }

    echo 1 | $SUDO tee /proc/sys/kernel/sysrq > /dev/null
    echo u | $SUDO tee /proc/sysrq-trigger > /dev/null
    $SUDO dd if="chr.img/chr-${CHR_VERSION}.img" bs=1024 of="$disk"
    sync
    echo s | $SUDO tee /proc/sysrq-trigger > /dev/null
    echo "sync disk please wait..."
    sleep 5
    echo "Installed, rebooting..."
    echo b | $SUDO tee /proc/sysrq-trigger > /dev/null
}

# Installs the "mik-help" command (downloads the latest installer each time,
# falls back to the cached copy if GitHub is not reachable)
install_shortcut() {
    if [ "$EUID" -ne 0 ] && ! command -v sudo &> /dev/null; then
        return 0
    fi
    $SUDO mkdir -p "$(dirname "$SHORTCUT_CACHE")" 2>/dev/null
    $SUDO tee "$SHORTCUT_BIN" > /dev/null <<'WRAP'
#!/bin/bash
SCRIPT_URL="__SCRIPT_URL__"
CACHE="__CACHE__"
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi
if curl -fsSL --max-time 10 "$SCRIPT_URL" -o "$CACHE.tmp" 2>/dev/null && [ -s "$CACHE.tmp" ]; then
    mv "$CACHE.tmp" "$CACHE"
fi
if [ ! -f "$CACHE" ]; then
    echo "Could not download the installer. Check your internet connection."
    exit 1
fi
exec bash "$CACHE" "$@"
WRAP
    $SUDO sed -i "s|__SCRIPT_URL__|$SCRIPT_URL|; s|__CACHE__|$SHORTCUT_CACHE|" "$SHORTCUT_BIN"
    $SUDO chmod +x "$SHORTCUT_BIN"
}

remove_shortcut() {
    $SUDO rm -f "$SHORTCUT_BIN" "$SHORTCUT_CACHE"
    echo "The mik-help command has been removed."
}

# Removes EVERYTHING this script installed: container, image, downloaded
# files and the mik-help command. (Docker itself is not removed.)
uninstall_all() {
    echo ""
    echo "=============================================================="
    echo " WARNING: this will completely remove:"
    echo " - the MikroTik container and ALL its settings"
    echo " - the MikroTik Docker image"
    echo " - downloaded installer files"
    echo " - the mik-help command"
    echo " Docker itself will NOT be removed."
    echo "=============================================================="
    read -p "Type YES to remove everything: " confirm
    [ "$confirm" == "YES" ] || { echo "Cancelled."; return 0; }

    if command -v docker &> /dev/null; then
        uninstall_mikrotik
    else
        echo "Docker is not installed, skipping container removal."
    fi

    rm -f "$IMAGE_ARCHIVE" "$IMAGE_FILE" chr.img.zip get-docker.sh
    rm -rf chr.img
    remove_shortcut
    echo "Everything has been removed."
}

menu() {
    clear
    echo "-------MikroTik Installer-------"
    echo "Select an option:"
    echo "1) Install MikroTik CHR (ERASES the whole disk!)"
    echo "----------------------------"
    echo "2) Install MikroTik via Docker"
    echo "3) Uninstall MikroTik via Docker"
    echo "4) Recreate Docker container with new ports"
    echo "5) Uninstall All"
    echo "----------------------------"
    echo "0) Exit"
    if [ -x "$SHORTCUT_BIN" ]; then
        echo ""
        echo "Tip: type 'mik-help' anywhere in SSH to open this menu."
    fi
}

install_shortcut
menu
read -p "Enter your choice: " choice

case $choice in
    1) install_chr_image ;;
    2) install_mikrotik ;;
    3) uninstall_mikrotik ;;
    4) recreate_mikrotik ;;
    5) uninstall_all ;;
    0) exit ;;
    *) echo "Invalid choice. Please select a valid option." ;;
esac
