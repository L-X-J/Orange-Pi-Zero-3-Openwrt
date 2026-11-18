# SPDX-License-Identifier: GPL-3.0-or-later
#
# Prebuilt OpenClash Meta core for aarch64 (Orange Pi Zero 3, H618).
# The tarball contains a single statically linked `clash` binary; OpenClash
# expects it at /etc/openclash/core/clash_meta.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=openclash-core
PKG_VERSION:=2026.10.12
PKG_RELEASE:=1

PKG_SOURCE:=clash-linux-arm64.tar.gz
PKG_SOURCE_URL:=https://raw.githubusercontent.com/vernesong/OpenClash/83506f9171511cbeaa358d583e2c8776529657b2/master/meta
PKG_HASH:=aae510c46001b8784b1480be94c3c740db9b387e5419604abaafa4189cd99c6d

PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=OpenClash

include $(INCLUDE_DIR)/package.mk

# Statically linked prebuilt core: never re-strip it.
RSTRIP:=:
STRIP:=:

define Package/openclash-core
  SECTION:=net
  CATEGORY:=Network
  TITLE:=OpenClash Meta core (aarch64)
  DEPENDS:=@aarch64
endef

define Package/openclash-core/description
  Prebuilt OpenClash Meta core (linux-arm64) bundled so OpenClash does not
  have to download a core on first start.
endef

define Build/Compile
endef

define Package/openclash-core/install
	$(INSTALL_DIR) $(1)/etc/openclash/core
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clash $(1)/etc/openclash/core/clash_meta
endef

$(eval $(call BuildPackage,openclash-core))
