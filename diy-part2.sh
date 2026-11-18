#!/bin/bash
#
# OpenWrt DIY script part 2 (after "scripts/feeds update/install")
# Target: ImmortalWrt openwrt-24.10 / Linux 6.6 LTS
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Router-mode management IP: 192.168.1.1 -> 192.168.44.1
# config_generate is the source of the default LAN address baked into
# /etc/config/network. files/etc/uci-defaults/99-orangepi-router then moves
# eth0 to WAN, enables LAN DHCP and sets the Wi-Fi SSID/password.
# ---------------------------------------------------------------------------
CONFIG_GENERATE="package/base-files/files/bin/config_generate"
[ -f "$CONFIG_GENERATE" ] || {
	echo "ERROR: $CONFIG_GENERATE not found" >&2
	exit 1
}

sed -i 's/192\.168\.1\.1/192.168.44.1/g' "$CONFIG_GENERATE"
grep -q '192\.168\.44\.1' "$CONFIG_GENERATE" || {
	echo "ERROR: failed to set default LAN IP" >&2
	exit 1
}
echo "Default LAN IP set to 192.168.44.1"

# ---------------------------------------------------------------------------
# No master / 6.18-specific overrides are applied:
#   * sunxi xunlong_orangepi-zero3 is natively supported by 24.10
#   * firewall4/nftables is the 24.10 default, so no S19firewall workaround
#   * kernel/Wi-Fi fixes live in diy-part1.sh and target the 6.6 tree
# Keep this file free of 6.18-only patches or forced kernel version bumps.
# ---------------------------------------------------------------------------
