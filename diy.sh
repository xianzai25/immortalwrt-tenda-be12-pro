#!/bin/bash
# Merged DIY script for OpenWrt build pipeline.

set -euo pipefail

STAGE="${1:-pre}"

case "$STAGE" in
  pre)
    ;;
  feeds)
    echo "=== 开始强制注入最新版 PassWall 源码并伪装为 PassWall2 ==="
    rm -rf feeds/passwall2
    mkdir -p feeds/passwall2
    git clone --depth=1 -b main https://github.com feeds/passwall2/temp_pw
    mv feeds/passwall2/temp_pw/luci-app-passwall feeds/passwall2/luci-app-passwall2
    rm -rf feeds/passwall2/temp_pw
    if [ -f "feeds/passwall2/luci-app-passwall2/Makefile" ]; then
      sed -i 's/luci-app-passwall/luci-app-passwall2/g' feeds/passwall2/luci-app-passwall2/Makefile
    fi
    rm -rf feeds/passwall_packages
    git clone --depth=1 -b main https://github.com feeds/passwall_packages
    rm -rf feeds/packages/lang/golang
    git clone --depth=1 https://github.com feeds/packages/lang/golang
    echo "=== 最新版 PassWall 源码及 Golang 环境伪装注入成功 ==="
    ;;
  post)
    base="defconfig/low-mem-512m/mt7987-mt7992-be7200.config"
    if [ ! -f "$base" ]; then
      echo "Missing upstream base defconfig: $base" >&2
      exit 1
    fi
    sed -e '/routerich_be7200/d' \
        -e '/CONFIG_PACKAGE_luci-app-upnp/d' \
        -e '/CONFIG_PACKAGE_miniupnpd-nftables/d' \
        -e '/CONFIG_PACKAGE_luci-i18n-upnp-zh-cn/d' \
        -e '/CONFIG_PACKAGE_luci-app-eqos-mtk/d' \
        "$base" > .config.base
    cat .config.base .config.delta > .config
    rm -f .config.base
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
