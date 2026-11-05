#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/port-forward.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"
export IPTABLES_LOG="$TMP/iptables.log"
export MIK_PORT_FORWARD_CONFIG="$TMP/ports.tsv"
export FAKE_IP_MODE=direct

cat > "$BIN/docker" <<'DOCKER_STUB'
#!/usr/bin/env bash
if [[ "$1" == "inspect" && "$2" == "-f" ]]; then
    case "$3" in
        *State.Running*) printf 'true\n' ;;
        *IPAddress*) printf '172.17.0.2\n' ;;
        *) exit 2 ;;
    esac
    exit 0
fi
exit 2
DOCKER_STUB

cat > "$BIN/ip" <<'IP_STUB'
#!/usr/bin/env bash
case "$*" in
    "-4 route get 1.1.1.1")
        case "${FAKE_IP_MODE:-direct}" in
            direct) printf '1.1.1.1 via 172.17.0.1 dev eth0 src 203.0.113.10\n' ;;
            default|none) exit 0 ;;
        esac
        ;;
    "-4 route show default")
        case "${FAKE_IP_MODE:-direct}" in
            default) printf 'default via 192.0.2.1 dev ens3\n' ;;
            direct|none) exit 0 ;;
        esac
        ;;
    "link show dev eth0"|"link show dev ens3") exit 0 ;;
    *) exit 2 ;;
esac
IP_STUB

cat > "$BIN/iptables" <<'IPTABLES_STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$IPTABLES_LOG"
for arg in "$@"; do
    [[ "$arg" == "-C" ]] && exit 1
done
exit 0
IPTABLES_STUB

chmod +x "$BIN/docker" "$BIN/ip" "$BIN/iptables"
printf '1701\t1701\tudp\n500\t500\tudp\n4500\t4500\tudp\n' > "$MIK_PORT_FORWARD_CONFIG"

run_helper() {
    if [[ "$EUID" -eq 0 ]]; then
        env PATH="$BIN:$PATH" bash "$SCRIPT" apply
    else
        sudo env PATH="$BIN:$PATH" MIK_PORT_FORWARD_CONFIG="$MIK_PORT_FORWARD_CONFIG" IPTABLES_LOG="$IPTABLES_LOG" FAKE_IP_MODE="$FAKE_IP_MODE" bash "$SCRIPT" apply
    fi
}

assert_rule_interface() {
    local interface="$1" port="$2"
    grep -F -- "-A MIK_HELP_NAT -i $interface -p udp --dport $port -j DNAT --to-destination 172.17.0.2:$port" "$IPTABLES_LOG" >/dev/null
}

: > "$IPTABLES_LOG"
run_helper >/dev/null
assert_rule_interface eth0 1701
assert_rule_interface eth0 500
assert_rule_interface eth0 4500
if grep -E -- '-A MIK_HELP_NAT .* -p (tcp|udp)' "$IPTABLES_LOG" | grep -v -- ' -i eth0 ' >/dev/null; then
    echo "FAIL: found an unscoped DNAT rule" >&2
    exit 1
fi

: > "$IPTABLES_LOG"
FAKE_IP_MODE=default run_helper >/dev/null
assert_rule_interface ens3 1701

: > "$IPTABLES_LOG"
if FAKE_IP_MODE=none run_helper >/dev/null 2>&1; then
    echo "FAIL: helper should refuse to rebuild rules without a detectable public interface" >&2
    exit 1
fi
if grep -F -- '-A MIK_HELP_NAT' "$IPTABLES_LOG" >/dev/null; then
    echo "FAIL: helper installed DNAT rules without a public interface" >&2
    exit 1
fi

echo "PASS: DNAT rules are restricted to the detected public interface."
echo "PASS: Docker-bridge traffic cannot match managed DNAT rules."
echo "PASS: default-route fallback and fail-closed behavior are covered."
