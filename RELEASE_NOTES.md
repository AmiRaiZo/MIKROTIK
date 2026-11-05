# Release notes

## 1.0.1

- Restrict managed DNAT rules to the host's public IPv4 ingress interface selected from the default route.
- Prevent connections arriving from Docker bridge interfaces from being redirected back into the MikroTik container.
- Fail closed without deleting active forwarding rules when the public interface cannot be identified.
- Add regression coverage for UDP 1701, 500 and 4500, default-route fallback, and missing-route behavior.
- Refresh the installer cache key and pin the port-forward helper to its corrected commit.
