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
#  - Removed the destructive "dd" CHR option and the resolv.conf overwrite

CONTAINER="livekadeh_com_mikrotik7_7"
IMAGE_ARCHIVE="Docker-image-Mikrotik-7.7-L6.7z"
IMAGE_FILE="mikrotik7.7_docker_livekadeh.com"
IMAGE_URL="https://github.com/Ptechgithub/MIKROTIK/releases/download/L6/${IMAGE_ARCHIVE}"

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
        echo "MikroTik container already exists. Use option 2 to recreate it with new ports."
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
    ask_ports || exit 1
    echo "NOTE: RouterOS config is lost unless you export it first (/export file=backup)."
    read -p "Remove the existing container and recreate it? (y/n): " confirm
    [ "$confirm" == "y" ] || { echo "Cancelled."; exit 0; }
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

menu() {
    clear
    echo "-------MikroTik Docker Installer-------"
    echo "Select an option:"
    echo "1) Install MikroTik via Docker"
    echo "2) Recreate container with new ports"
    echo "3) Uninstall MikroTik via Docker"
    echo "0) Exit"
}

menu
read -p "Enter your choice: " choice

case $choice in
    1) install_mikrotik ;;
    2) recreate_mikrotik ;;
    3) uninstall_mikrotik ;;
    0) exit ;;
    *) echo "Invalid choice. Please select a valid option." ;;
esac
