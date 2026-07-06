#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/local_menuconfig.sh"

test -f "$TARGET_SCRIPT"
grep -Fq 'OPENWRT_PATH=${OPENWRT_PATH:-/Volumes/OpenWrt/lede}' "$TARGET_SCRIPT"
grep -Fq 'WRT_DIY_FEEDS=${WRT_DIY_FEEDS:-diy_feeds.sh}' "$TARGET_SCRIPT"
grep -Fq 'WRT_FIREWALL=${WRT_FIREWALL:-auto}' "$TARGET_SCRIPT"
grep -Fq 'WRT_DIYPackages=${WRT_DIYPackages:-auto}' "$TARGET_SCRIPT"
grep -Fq 'WRT_THEME_NAME=${WRT_THEME_NAME:-auto}' "$TARGET_SCRIPT"
grep -Fq 'resolve_device_script.sh' "$TARGET_SCRIPT"
grep -Fq 'WRT_RESOLVED_DIY_PACKAGES=$(' "$TARGET_SCRIPT"
grep -Fq '实际自定义包脚本：$WRT_RESOLVED_DIY_PACKAGES' "$TARGET_SCRIPT"
grep -Fq 'LOCAL_SKIP_MENUCONFIG=${LOCAL_SKIP_MENUCONFIG:-false}' "$TARGET_SCRIPT"
grep -Fq 'LOCAL_CLEAN_GENERATED=${LOCAL_CLEAN_GENERATED:-true}' "$TARGET_SCRIPT"
grep -Fq 'infer_default_overlays_for_device "$CONFIG_ROOT" "$WRT_DEVICE" "$WRT_FIREWALL"' "$TARGET_SCRIPT"
grep -Fq 'merge_overlay_csv_lists "$CONFIG_ROOT" "$auto_overlays" "$WRT_OVERLAYS"' "$TARGET_SCRIPT"
grep -Fq 'git fetch --depth=1 origin "${WRT_SOURCE_HASH_INFO}"' "$TARGET_SCRIPT"
grep -Fq 'rm -rf ./staging_dir ./tmp ./logs ./package/feeds ./bin ./build_dir ./toolchain ./feeds' "$TARGET_SCRIPT"
grep -Fq 'mkdir -p ./feeds' "$TARGET_SCRIPT"
grep -Fq 'perl ./scripts/feeds update -a' "$TARGET_SCRIPT"
grep -Fq 'perl ./scripts/feeds install -a' "$TARGET_SCRIPT"
grep -Fq 'bash "$SCRIPT_ROOT/$WRT_DIY_FEEDS"' "$TARGET_SCRIPT"
grep -Fq 'bash "$SCRIPT_ROOT/export_config.sh" "${EXPORT_ARGS[@]}"' "$TARGET_SCRIPT"
grep -Fq 'make menuconfig' "$TARGET_SCRIPT"
grep -Fq 'bash ./scripts/diffconfig.sh > seed.config' "$TARGET_SCRIPT"
grep -Fq 'WRT_CONFIG_LABEL="${WRT_DEVICE}-${WRT_FIREWALL}"' "$TARGET_SCRIPT"
grep -Fq '. "$SOURCE_TYPE_LIB"' "$TARGET_SCRIPT"
grep -Fq 'SOURCE_TYPE=$(resolve_source_type "${SOURCE_TYPE:-auto}" "$OPENWRT_PATH")' "$TARGET_SCRIPT"
grep -Fq 'SOURCE_CONFIG_FAMILY=$(source_config_family "$SOURCE_TYPE")' "$TARGET_SCRIPT"
if grep -Fq '支持 lean、iwrt、vwrt、libwrt' "$TARGET_SCRIPT"; then
	echo "local_menuconfig.sh should not expose iwrt as a SOURCE_TYPE option" >&2
	exit 1
fi
grep -Fq 'PATH="${LOCAL_COMPAT_DIR}:$PATH"' "$TARGET_SCRIPT"
grep -Fq 'exec /usr/bin/sed -i "" "$@"' "$TARGET_SCRIPT"
if grep -Fq 'apk 与 ipk 不能同时启用' "$TARGET_SCRIPT"; then
	echo "local_menuconfig.sh should normalize mutually exclusive overlays instead of erroring" >&2
	exit 1
fi
if grep -Fq 'WRT_FIREWALL^^' "$TARGET_SCRIPT"; then
	echo "local_menuconfig.sh should stay compatible with macOS bash 3.2" >&2
	exit 1
fi

echo "test_local_menuconfig: ok"
