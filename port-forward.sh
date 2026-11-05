#!/usr/bin/env bash
# Public TCP/UDP port forwarding into the MikroTik Docker container.
# Rules are independent of Docker published ports and do not recreate the container.
set -euo pipefail

CONTAINER="livekadeh_com_mikrotik7_7"
CONFIG="${MIK_PORT_FORWARD_CONFIG:-/etc/mikrotik-port-forward/ports.tsv}"
NAT_CHAIN="MIK_HELP_NAT"
FILTER_CHAIN="MIK_HELP_FILTER"

die() { echo "ERROR: $*" >&2; exit 1; }

normalize_port() {
    local value="$1"
    [[ "$value" =~ ^[0-9]{1,5}$ ]] || return 1
    value=$((10#$value))
    (( value >= 1 && value <= 65535 )) || return 1
    printf '%s' "$value"
}

normalize_protocol() {
    local value
    value=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    [[ "$value" == "tcp" || "$value" == "udp" ]] || return 1
    printf '%s' "$value"
}

# Resolve the host interface used to reach the public IPv4 internet.
# Bind every DNAT rule to this ingress interface so Docker bridge traffic cannot
# be redirected back into the same MikroTik container.
detect_public_interface() {
    local route_result interface
    command -v ip >/dev/null 2>&1 || return 1

    route_result=$(ip -4 route get 1.1.1.1 2>/dev/null | head -n1 || true)
    interface=$(awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}' <<< "$route_result")

    if [[ -z "$interface" ]]; then
        route_result=$(ip -4 route show default 2>/dev/null | head -n1 || true)
        interface=$(awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}' <<< "$route_result")
    fi

    [[ -n "$interface" ]] || return 1
    ip link show dev "$interface" >/dev/null 2>&1 || return 1
    printf '%s' "$interface"
}

remove_filter_jump() {
    local parent="$1"
    while iptables -C "$parent" -j "$FILTER_CHAIN" >/dev/null 2>&1; do
        iptables -D "$parent" -j "$FILTER_CHAIN" || break
    done
}

remove_nat_jump() {
    while iptables -t nat -C PREROUTING -j "$NAT_CHAIN" >/dev/null 2>&1; do
        iptables -t nat -D PREROUTING -j "$NAT_CHAIN" || break
    done
}

apply_rules() {
    command -v docker >/dev/null 2>&1 || die "Docker command not found."
    command -v iptables >/dev/null 2>&1 || die "iptables command not found."
    mkdir -p "$(dirname "$CONFIG")"
    touch "$CONFIG"

    if [[ ! -s "$CONFIG" ]]; then
        remove_nat_jump
        remove_filter_jump "DOCKER-USER"
        remove_filter_jump "FORWARD"
        iptables -t nat -F "$NAT_CHAIN" 2>/dev/null || true
        iptables -F "$FILTER_CHAIN" 2>/dev/null || true
        echo "No managed public ports are open."
        return 0
    fi

    local container_ip=""
    local attempt public_port target_port protocol public_interface
    for attempt in $(seq 1 30); do
        if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" == "true" ]]; then
            container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{if .IPAddress}}{{.IPAddress}}{{"\n"}}{{end}}{{end}}' "$CONTAINER" 2>/dev/null | head -n1)
        fi
        [[ -n "$container_ip" ]] && break
        sleep 1
    done
    [[ -n "$container_ip" ]] || die "MikroTik Docker container is not running or has no bridge IP."

    public_interface=$(detect_public_interface) || die "Could not detect the public IPv4 interface. Existing forwarding rules were left unchanged."
    iptables -t nat -N "$NAT_CHAIN" 2>/dev/null || true
    iptables -N "$FILTER_CHAIN" 2>/dev/null || true
    iptables -t nat -F "$NAT_CHAIN"
    iptables -F "$FILTER_CHAIN"
    remove_nat_jump
    remove_filter_jump "DOCKER-USER"
    remove_filter_jump "FORWARD"

    while IFS=$'\t' read -r public_port target_port protocol; do
        [[ -z "$public_port" ]] && continue
        public_port=$(normalize_port "$public_port") || die "Invalid public port in $CONFIG."
        target_port=$(normalize_port "$target_port") || die "Invalid target port in $CONFIG."
        protocol=$(normalize_protocol "$protocol") || die "Invalid protocol in $CONFIG."

        iptables -t nat -A "$NAT_CHAIN" -i "$public_interface" -p "$protocol" --dport "$public_port" \
            -j DNAT --to-destination "$container_ip:$target_port"
        iptables -A "$FILTER_CHAIN" -d "$container_ip" -p "$protocol" --dport "$target_port" \
            -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
    done < "$CONFIG"

    iptables -t nat -I PREROUTING 1 -j "$NAT_CHAIN"
    if iptables -nL DOCKER-USER >/dev/null 2>&1; then
        iptables -I DOCKER-USER 1 -j "$FILTER_CHAIN"
    else
        iptables -I FORWARD 1 -j "$FILTER_CHAIN"
    fi

    echo "Forwarding rules applied to MikroTik container IP $container_ip via public interface $public_interface."
}

port_in_use() {
    local port="$1"
    if docker port "$CONTAINER" 2>/dev/null | awk -v p="$port" '$NF ~ (":" p "$") { found=1 } END { exit !found }'; then
        return 0
    fi
    if command -v ss >/dev/null 2>&1; then
        if ss -H -lntup 2>/dev/null | awk -v p="$port" '$5 ~ (":" p "$") { found=1 } END { exit !found }'; then
            return 0
        fi
    fi
    return 1
}

open_port() {
    local public_port target_port protocol tmp
    public_port=$(normalize_port "$1") || die "Public port must be a number from 1 to 65535."
    target_port=$(normalize_port "$2") || die "MikroTik target port must be a number from 1 to 65535."
    protocol=$(normalize_protocol "$3") || die "Protocol must be TCP or UDP."

    mkdir -p "$(dirname "$CONFIG")"
    touch "$CONFIG"

    if awk -F '\t' -v p="$public_port" -v pr="$protocol" '$1 == p && $3 == pr { found=1 } END { exit !found }' "$CONFIG"; then
        die "This public port/protocol is already managed."
    fi
    if port_in_use "$public_port"; then
        die "Public port $public_port is already published by Docker or used by a host service."
    fi

    printf '%s\t%s\t%s\n' "$public_port" "$target_port" "$protocol" >> "$CONFIG"
    if ! apply_rules; then
        tmp=$(mktemp)
        awk -F '\t' -v p="$public_port" -v pr="$protocol" '!( $1 == p && $3 == pr )' "$CONFIG" > "$tmp"
        mv "$tmp" "$CONFIG"
        apply_rules || true
        return 1
    fi
    echo "Opened: SERVER_PUBLIC_IP:$public_port/$protocol -> MikroTik:$target_port"
}

close_port() {
    local public_port protocol tmp
    public_port=$(normalize_port "$1") || die "Public port must be a number from 1 to 65535."
    protocol=$(normalize_protocol "$2") || die "Protocol must be TCP or UDP."
    [[ -f "$CONFIG" ]] || die "No managed public ports are configured."

    tmp=$(mktemp)
    if ! awk -F '\t' -v p="$public_port" -v pr="$protocol" '
        $1 == p && $3 == pr { found=1; next }
        { print }
        END { if (!found) exit 1 }
    ' "$CONFIG" > "$tmp"; then
        rm -f "$tmp"
        die "Port $public_port/$protocol was not found."
    fi
    mv "$tmp" "$CONFIG"
    apply_rules
    echo "Closed: SERVER_PUBLIC_IP:$public_port/$protocol"
}

list_ports() {
    local public_port target_port protocol
    if [[ ! -s "$CONFIG" ]]; then
        echo "No managed public ports are open."
        return 0
    fi
    printf '%-14s %-14s %-8s\n' "PUBLIC PORT" "MIKROTIK PORT" "PROTOCOL"
    printf '%-14s %-14s %-8s\n' "-----------" "-------------" "--------"
    while IFS=$'\t' read -r public_port target_port protocol; do
        [[ -z "$public_port" ]] && continue
        printf '%-14s %-14s %-8s\n' "$public_port" "$target_port" "$protocol"
    done < "$CONFIG"
}

clear_rules() {
    command -v iptables >/dev/null 2>&1 || die "iptables command not found."
    remove_nat_jump
    remove_filter_jump "DOCKER-USER"
    remove_filter_jump "FORWARD"
    iptables -t nat -F "$NAT_CHAIN" 2>/dev/null || true
    iptables -F "$FILTER_CHAIN" 2>/dev/null || true
    echo "Managed port-forwarding rules cleared."
}

watch_rules() {
    while true; do
        apply_rules || true
        docker events --filter "container=$CONTAINER" --filter "event=start" --format '{{.Action}}' 2>/dev/null |
            while IFS= read -r event; do
                sleep 2
                apply_rules || true
            done
        sleep 2
    done
}

[[ "$EUID" -eq 0 ]] || die "Run this helper as root."
case "$1" in
    open)  [[ "$#" -eq 4 ]] || die "Usage: mik-port-forward open PUBLIC_PORT MIKROTIK_PORT tcp|udp"; open_port "$2" "$3" "$4" ;;
    close) [[ "$#" -eq 3 ]] || die "Usage: mik-port-forward close PUBLIC_PORT tcp|udp"; close_port "$2" "$3" ;;
    list)  list_ports ;;
    apply) apply_rules ;;
    clear) clear_rules ;;
    watch) watch_rules ;;
    *) die "Usage: mik-port-forward {open|close|list|apply|watch}" ;;
esac
