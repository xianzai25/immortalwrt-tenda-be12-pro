#!/bin/bash
# Merged DIY script for OpenWrt build pipeline.

set -euo pipefail

STAGE="${1:-pre}"

case "$STAGE" in
  pre)
    ;;

  feeds)
    # 强制提升编译内核所需的 Golang 版本，防止新版内核因 Go 版本过旧编译失败
    rm -rf feeds/packages/lang/golang
    git clone --depth=1 https://github.com feeds/packages/lang/golang
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

    # 默认管理 IP 改为 192.168.3.1
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
