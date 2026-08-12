#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW3_WIFI_OUT="$TMPDIR/gl-mt6000-wifi-fw3.txt"
FW3_NOWIFI_OUT="$TMPDIR/gl-mt6000-nowifi-fw3.txt"
FW4_WIFI_OUT="$TMPDIR/gl-mt6000-wifi-fw4.txt"
FW4_NOWIFI_OUT="$TMPDIR/gl-mt6000-nowifi-fw4.txt"

SOURCE_TYPE=lean bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "gl-mt6000-wifi" \
	--fw "fw3" \
	--output "$FW3_WIFI_OUT" >/dev/null

SOURCE_TYPE=lean bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "gl-mt6000-nowifi" \
	--fw "fw3" \
	--output "$FW3_NOWIFI_OUT" >/dev/null

SOURCE_TYPE=vwrt bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "gl-mt6000-wifi" \
	--fw "fw4" \
	--output "$FW4_WIFI_OUT" >/dev/null

SOURCE_TYPE=vwrt bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "gl-mt6000-nowifi" \
	--fw "fw4" \
	--output "$FW4_NOWIFI_OUT" >/dev/null

grep -n '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW3_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_glinet_gl-mt6000=y'
grep -n '^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_glinet_gl-mt6000=y'

grep -n '^CONFIG_PACKAGE_luci-app-wifischedule=' "$FW3_WIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wifischedule=y'
grep -n '^CONFIG_PACKAGE_luci-app-wifischedule=' "$FW3_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wifischedule=n'
grep -n '^CONFIG_PACKAGE_luci-app-wifischedule=' "$FW4_WIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wifischedule=y'
grep -n '^CONFIG_PACKAGE_luci-app-wifischedule=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wifischedule=n'

grep -n '^CONFIG_PACKAGE_luci-i18n-wifischedule-zh-cn=' "$FW3_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-wifischedule-zh-cn=n'
grep -n '^CONFIG_PACKAGE_luci-i18n-wifischedule-zh-cn=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-wifischedule-zh-cn=n'
grep -n '^CONFIG_PACKAGE_luci-app-guest-wifi=' "$FW3_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-guest-wifi=n'
grep -n '^CONFIG_PACKAGE_wpad-openssl=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-openssl=n'
grep -n '^CONFIG_PACKAGE_hostapd-common=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hostapd-common=n'
grep -n '^CONFIG_PACKAGE_kmod-mt7915e=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-mt7915e=n'
grep -n '^CONFIG_PACKAGE_kmod-mt7986-firmware=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-mt7986-firmware=n'
grep -n '^CONFIG_PACKAGE_mt7986-wo-firmware=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_mt7986-wo-firmware=n'
grep -n '^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW3_NOWIFI_OUT" | tail -n 1 | grep -q -- '-kmod-mt7915e'
grep -n '^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q -- '-kmod-mt7915e'
grep -n '^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q -- '-kmod-mt76-core'
grep -n '^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q -- '-kmod-mt76-connac'
grep -n '^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q -- '-kmod-mac80211'
grep -n '^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q -- '-cfg80211'
grep -n '^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q -- '-kmod-mt7986-firmware'
grep -n '^CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_glinet_gl-mt6000=' "$FW4_NOWIFI_OUT" | tail -n 1 | grep -q -- '-wpad-basic-mbedtls'

echo "test_gl_mt6000_nowifi_overlay: ok"
