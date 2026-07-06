#!/bin/bash

# 说明：CMIOT-AX18 的一组设备共用包与 FW3 设备差异。
# `*-nowifi` 目标通过 `Config/cmiot-ax18-wifi-fw3.txt` + nowifi overlay 导出。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW3_OUT="$TMPDIR/fw3.txt"
FW4_OUT="$TMPDIR/fw4.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "cmiot-ax18-nowifi" \
	--fw "fw3" \
	--output "$FW3_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "cmiot-ax18-nowifi" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

for output in "$FW3_OUT" "$FW4_OUT"; do
	grep -n '^CONFIG_PACKAGE_luci-app-openclash=' "$output" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openclash=[ym]'
done

grep -n '^CONFIG_PACKAGE_luci-app-openlist=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-openlist=m'
grep -n '^CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=m'
grep -n '^CONFIG_PACKAGE_luci-app-wrtbwmon=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wrtbwmon=[ym]'
grep -n '^CONFIG_PACKAGE_luci-i18n-wrtbwmon-zh-cn=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-wrtbwmon-zh-cn=[ym]'
grep -n '^CONFIG_PACKAGE_wrtbwmon=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wrtbwmon=[ym]'
grep -n '^CONFIG_PACKAGE_kmod-mac80211=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-mac80211=n'
grep -n '^CONFIG_PACKAGE_cfg80211=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_cfg80211=n'
grep -n '^CONFIG_PACKAGE_wpad-basic-mbedtls=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-basic-mbedtls=n'
grep -n '^CONFIG_PACKAGE_hostapd=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hostapd=n'
grep -n '^CONFIG_PACKAGE_iw=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iw=n'
grep -n '^CONFIG_PACKAGE_iwinfo=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iwinfo=n'
grep -n '^CONFIG_PACKAGE_wireless-regdb=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wireless-regdb=n'
grep -n '^CONFIG_PACKAGE_kmod-mac80211=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-mac80211=n'
grep -n '^CONFIG_PACKAGE_cfg80211=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_cfg80211=n'
grep -n '^CONFIG_PACKAGE_wpad-basic-mbedtls=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-basic-mbedtls=n'
grep -n '^CONFIG_PACKAGE_hostapd=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hostapd=n'
grep -n '^CONFIG_PACKAGE_iw=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iw=n'
grep -n '^CONFIG_PACKAGE_iwinfo=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iwinfo=n'
grep -n '^CONFIG_PACKAGE_wireless-regdb=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wireless-regdb=n'

echo "test_cmiot_ax18_shared_packages: ok"
