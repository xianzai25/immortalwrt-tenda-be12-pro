#!/bin/bash
#
# Merged DIY script for OpenWrt build pipeline.
# Usage:
#   ./diy.sh pre   # before feeds update/install
#   ./diy.sh feeds # after feeds update, before feeds install
#   ./diy.sh post  # after feeds install, before build

set -euo pipefail

STAGE="${1:-pre}"

case "$STAGE" in
  pre)
    # Reserved for future pre-feed tweaks.
    ;;

  feeds)
    # 自动拉取/更新并切换到最新 passwall2 及其依赖源（不锁定旧 commit，确保获取最新）
    PASSWALL2_REF="${PASSWALL2_REF:-HEAD}"
    PASSWALL_PACKAGES_REF="${PASSWALL_PACKAGES_REF:-HEAD}"

    if [ -d feeds/passwall2/.git ]; then
      git -C feeds/passwall2 fetch --depth=1 origin
      git -C feeds/passwall2 checkout --detach origin/main || git -C feeds/passwall2 checkout --detach origin/master
    fi
    if [ -d feeds/passwall_packages/.git ]; then
      git -C feeds/passwall_packages fetch --depth=1 origin
      git -C feeds/passwall_packages checkout --detach origin/main || git -C feeds/passwall_packages checkout --detach origin/master
    fi
    ;;

  post)
    # Base config: upstream's official MT7987+MT7992 Wi-Fi 7 defconfig.
    # It carries the whole closed-source MTK wifi7 driver stack (kmod-mt_wifi7,
    # kmod-mt_hwifi, kmod-mt7992, warp, wifi-profile/l1profile) and — critically —
    # selects DRIVER_11BE_SUPPORT, without which hostapd fails to build against
    # the tree's MLO patches. Our .config is layered on top as a delta.
    base="defconfig/low-mem-512m/mt7987-mt7992-be7200.config"
    if [ ! -f "$base" ]; then
      echo "Missing upstream base defconfig: $base" >&2
      exit 1
    fi
    # Drop the co-built Routerich device; keep BE12 Pro only.
    # Also strip packages we deliberately remove from the base (UPnP, Easy QoS).
    sed -e '/routerich_be7200/d' \
        -e '/CONFIG_PACKAGE_luci-app-upnp/d' \
        -e '/CONFIG_PACKAGE_miniupnpd-nftables/d' \
        -e '/CONFIG_PACKAGE_luci-i18n-upnp-zh-cn/d' \
        -e '/CONFIG_PACKAGE_luci-app-eqos-mtk/d' \
        "$base" > .config.base
    cat .config.base .config.delta > .config
    rm -f .config.base

    # Default LAN IP 192.168.1.1 -> 192.168.3.1.
    cfg_file="package/base-files/files/bin/config_generate"
    if [ -f "$cfg_file" ]; then
      sed -i 's/192\.168\.1\.1/192.168.3.1/g' "$cfg_file"
    else
      echo "Missing file: $cfg_file" >&2
      exit 1
    fi
    ;;

  *)
    echo "Unknown stage: $STAGE (expected: pre|feeds|post)" >&2
    exit 1
    ;;
esac
