#!/bin/bash
#
# OpenWrt DIY script part 1 (before "scripts/feeds update")
# Target: ImmortalWrt openwrt-24.10 / Linux 6.6 LTS
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Onboard AW859A (Unisoc UWE5622) Wi-Fi for Orange Pi Zero 3
#
# openwrt-24.10 has the Zero 3 target and DTS, but it does NOT provide
# kmod-uwe5622 / uwe5622-firmware: those only exist on ImmortalWrt master,
# which is Linux 6.18 and not ABI-compatible with this 6.6 build.
#
# Use the 24.10/6.6 backport (mac80211 backports patch set + firmware package
# + the sun50i-h616 Zero 2/Zero 3 Wi-Fi DTS node). The commit is pinned so a
# rolling upstream branch cannot silently change the driver.
# Upstream: https://github.com/DeepAQ/openwrt-uwe5622-sunxi
# ---------------------------------------------------------------------------
UWE5622_REPO="https://github.com/DeepAQ/openwrt-uwe5622-sunxi.git"
UWE5622_COMMIT="0539b491bc4552bd74e9d7bd79eb6df715b5b5b8"
UWE5622_SRC="$(mktemp -d)"
trap 'rm -rf "$UWE5622_SRC"' EXIT

echo "==> Backporting UWE5622 Wi-Fi driver for openwrt-24.10"
git clone --filter=blob:none "$UWE5622_REPO" "$UWE5622_SRC"
git -C "$UWE5622_SRC" checkout -q "$UWE5622_COMMIT"

# Driver patches are applied by the mac80211 package (PATCH_DIR/unisoc).
rm -rf package/kernel/mac80211/patches/unisoc
cp -r "$UWE5622_SRC/package/kernel/mac80211/patches/unisoc" \
	package/kernel/mac80211/patches/
cp "$UWE5622_SRC/package/kernel/mac80211/unisoc.mk" \
	package/kernel/mac80211/

# The tty-sdio (Bluetooth) module calls rtc_time64_to_tm(), which the 24.10
# sunxi kernel does not export to modules -> modpost failure. Wi-Fi does not
# need it, so build only sprdwl_ng + uwe5622_bsp_sdio and skip sprdbt_tty.
awk '
	/TTY_OVERY_SDIO/ { sub(/ TTY_OVERY_SDIO/, "") }
	/sprdbt_tty\.ko/ { next }
	/uwe5622_bsp_sdio\.ko \\$/ { sub(/ \\$/, "") }
	{ print }
' package/kernel/mac80211/unisoc.mk > package/kernel/mac80211/unisoc.mk.tmp
mv package/kernel/mac80211/unisoc.mk.tmp package/kernel/mac80211/unisoc.mk

# Enable the driver inside ImmortalWrt's mac80211 Makefile.
if ! grep -q '^include unisoc\.mk$' package/kernel/mac80211/Makefile; then
	awk '
		/^include realtek\.mk$/ {
			print
			print "include unisoc.mk"
			next
		}
		/rtl,rtl\// {
			print
			if ($0 ~ /Quilt/)
				print "\t$(call Quilt/RefreshDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/unisoc,unisoc/)"
			else
				print "\t$(call PatchDir,$(PKG_BUILD_DIR),$(PATCH_DIR)/unisoc,unisoc/)"
			next
		}
		{ print }
	' package/kernel/mac80211/Makefile > package/kernel/mac80211/Makefile.tmp
	mv package/kernel/mac80211/Makefile.tmp package/kernel/mac80211/Makefile
fi

# DTS: enable mmc1 / Wi-Fi regulators / pwrseq for Zero 2 and Zero 3.
cp "$UWE5622_SRC/target/linux/sunxi/patches-6.6/arm64-dts-h616-add-wifi-support-for-orange-pi-zero-2-and-zero3.patch" \
	target/linux/sunxi/patches-6.6/

# 24.10's armbian-firmware already pins an armbian/firmware commit that
# contains uwe5622/wcnmodem*.bin, so only add the missing sub-package.
if ! grep -q '^define Package/uwe5622-firmware$' package/firmware/armbian-firmware/Makefile; then
	cat >>package/firmware/armbian-firmware/Makefile <<'EOF'

define Package/uwe5622-firmware
  $(call Package/armbian-firmware-default,Unisoc UWE5622 (AW859A) firmware)
endef

define Package/uwe5622-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_DATA) \
		$(PKG_BUILD_DIR)/uwe5622/wcnmodem.bin \
		$(PKG_BUILD_DIR)/uwe5622/wcnmodem-38222.bin \
		$(PKG_BUILD_DIR)/uwe5622/wifi_2355b001_1ant.ini \
		$(1)/lib/firmware/
endef

$(eval $(call BuildPackage,uwe5622-firmware))
EOF
fi

# ---------------------------------------------------------------------------
# Bundle the OpenClash Meta core. The package downloads the pinned aarch64
# core tarball and installs it as /etc/openclash/core/clash_meta, so a fresh
# image already has a working Clash core without visiting the update page.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
rm -rf package/openclash-core
cp -r "$SCRIPT_DIR/openclash-core" package/openclash-core
test -f package/openclash-core/Makefile

# Fail fast if the integration did not take.
grep -q '^include unisoc\.mk$' package/kernel/mac80211/Makefile
grep -q 'PATCH_DIR)/unisoc' package/kernel/mac80211/Makefile
test -d package/kernel/mac80211/patches/unisoc
test -f target/linux/sunxi/patches-6.6/arm64-dts-h616-add-wifi-support-for-orange-pi-zero-2-and-zero3.patch
grep -q '^define Package/uwe5622-firmware$' package/firmware/armbian-firmware/Makefile
grep -q 'sprdwl_ng\.ko' package/kernel/mac80211/unisoc.mk
grep -q 'uwe5622_bsp_sdio\.ko' package/kernel/mac80211/unisoc.mk
! grep -q 'TTY_OVERY_SDIO' package/kernel/mac80211/unisoc.mk
! grep -q 'sprdbt_tty' package/kernel/mac80211/unisoc.mk

# ---------------------------------------------------------------------------
# Third-party feeds are declared in feeds.conf.default. Keep this script free
# of ad-hoc package clones: aliyundrive-fuse / OpenAppFilter / docker_ddnsto
# were dropped because they are unrelated to a lean proxy router and pulled
# extra daemons into a 1GB board.
# ---------------------------------------------------------------------------
echo "diy-part1.sh done"
