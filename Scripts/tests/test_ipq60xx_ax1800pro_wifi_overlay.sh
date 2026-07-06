#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

BASE_OUT="$TMPDIR/ipq60xx-base.txt"
AX1800_OUT="$TMPDIR/jd-ax1800pro-wifi.txt"
NOWIFI_OUT="$TMPDIR/jd-ax1800pro-nowifi.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "cmiot-ax18-nowifi" \
	--fw "fw3" \
	--output "$BASE_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "jd-ax1800pro-wifi" \
	--fw "fw3" \
	--output "$AX1800_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "jd-ax1800pro-nowifi" \
	--fw "fw3" \
	--output "$NOWIFI_OUT" >/dev/null

grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=y'
grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=n'
grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=n'
grep -n '^CONFIG_PACKAGE_ath11k-firmware-ipq6018=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ath11k-firmware-ipq6018=n'
grep -n '^CONFIG_PACKAGE_wpad-openssl=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-openssl=n'
grep -n '^CONFIG_PACKAGE_kmod-mac80211=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-mac80211=n'
grep -n '^CONFIG_PACKAGE_cfg80211=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_cfg80211=n'
grep -n '^CONFIG_PACKAGE_wpad-basic-mbedtls=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-basic-mbedtls=n'
grep -n '^CONFIG_PACKAGE_hostapd=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hostapd=n'
grep -n '^CONFIG_PACKAGE_iw=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iw=n'
grep -n '^CONFIG_PACKAGE_iwinfo=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iwinfo=n'
grep -n '^CONFIG_PACKAGE_wireless-regdb=' "$BASE_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wireless-regdb=n'

grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_cmiot_ax18=n'
grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y'
if grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=n'; then
	echo "JD-AX1800PRO-WIFI should not disable kmod-ath11k" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_kmod-ath11k-ahb=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k-ahb=n'; then
	echo "JD-AX1800PRO-WIFI should not disable kmod-ath11k-ahb" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_ath11k-firmware-ipq6018=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ath11k-firmware-ipq6018=n'; then
	echo "JD-AX1800PRO-WIFI should not disable IPQ6018 firmware" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_wpad-openssl=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-openssl=n'; then
	echo "JD-AX1800PRO-WIFI should not disable wpad-openssl" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_hostapd-common=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hostapd-common=n'; then
	echo "JD-AX1800PRO-WIFI should not disable hostapd-common" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_kmod-mac80211=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-mac80211=n'; then
	echo "JD-AX1800PRO-WIFI should not disable kmod-mac80211" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_cfg80211=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_cfg80211=n'; then
	echo "JD-AX1800PRO-WIFI should not disable cfg80211" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_wpad-basic-mbedtls=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-basic-mbedtls=n'; then
	echo "JD-AX1800PRO-WIFI should not disable wpad-basic-mbedtls" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_hostapd=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hostapd=n'; then
	echo "JD-AX1800PRO-WIFI should not disable hostapd" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_iw=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iw=n'; then
	echo "JD-AX1800PRO-WIFI should not disable iw" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_iwinfo=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iwinfo=n'; then
	echo "JD-AX1800PRO-WIFI should not disable iwinfo" >&2
	exit 1
fi
if grep -n '^CONFIG_PACKAGE_wireless-regdb=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wireless-regdb=n'; then
	echo "JD-AX1800PRO-WIFI should not disable wireless-regdb" >&2
	exit 1
fi

if grep -n '^CONFIG_PACKAGE_ipq-wifi-jdcloud_re-ss-01=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ipq-wifi-jdcloud_re-ss-01=y'; then
	:
fi
if grep -n '^CONFIG_PACKAGE_ipq-wifi-jdcloud_re-ss-01=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_ipq-wifi-jdcloud_re-ss-01=y'; then
	echo "JD-AX1800PRO-NOWIFI should not enable jdcloud_re-ss-01 board data package" >&2
	exit 1
fi
grep -n '^CONFIG_PACKAGE_luci-app-wifischedule=' "$AX1800_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wifischedule=y'
grep -n '^CONFIG_PACKAGE_luci-app-wifischedule=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-app-wifischedule=n'
grep -n '^CONFIG_PACKAGE_luci-i18n-wifischedule-zh-cn=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_luci-i18n-wifischedule-zh-cn=n'
grep -n '^CONFIG_PACKAGE_kmod-mac80211=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-mac80211=n'
grep -n '^CONFIG_PACKAGE_cfg80211=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_cfg80211=n'
grep -n '^CONFIG_PACKAGE_wpad-basic-mbedtls=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-basic-mbedtls=n'
grep -n '^CONFIG_PACKAGE_hostapd=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_hostapd=n'
grep -n '^CONFIG_PACKAGE_iw=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iw=n'
grep -n '^CONFIG_PACKAGE_iwinfo=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_iwinfo=n'
grep -n '^CONFIG_PACKAGE_wireless-regdb=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wireless-regdb=n'

echo "test_jd_ax1800pro_wifi_export: ok"
