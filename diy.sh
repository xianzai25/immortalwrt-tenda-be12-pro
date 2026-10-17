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
    echo "=== 开始更新 PassWall2 插件与内核依赖为最新版 ==="
    
    # 1. 强制克隆最新版的 PassWall LuCI 界面 (main 分支)
    rm -rf feeds/passwall2
    git clone --depth=1 -b main https://github.com feeds/passwall2

    # 2. 强制克隆最新版的 PassWall 依赖核心（包含最新 Xray-core, Sing-box 等）
    rm -rf feeds/passwall_packages
    git clone --depth=1 -b main https://github.com feeds/passwall_packages

    # 3. 强制提升编译内核所需的 Golang 版本，防止新版内核因 Go 版本过旧编译失败
    rm -rf feeds/packages/lang/golang
    git clone --depth=1 https://github.com feeds/packages/lang/golang

    echo "=== PassWall2 及 Golang 环境更新完成 ==="
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
