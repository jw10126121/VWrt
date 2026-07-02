#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW3_OUT="$TMPDIR/jd-ax6600-fw3.txt"
FW4_OUT="$TMPDIR/jd-ax6600-fw4.txt"

assert_last_value() {
	local file=$1
	local key=$2
	local expected=$3
	local actual

	actual=$(
		grep -nE "^[#[:space:]]*${key}=" "$file" |
			tail -n 1 |
			sed -E 's/^[0-9]+://; s/^#[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//' |
			cut -d '=' -f 2- || true
	)
	if [ "$actual" != "$expected" ]; then
		echo "expected last ${key}=${expected}, got ${actual:-<missing>}" >&2
		exit 1
	fi
}

assert_no_active_value() {
	local file=$1
	local key=$2

	if grep -q "^${key}=" "$file"; then
		echo "did not expect active ${key} in exported config" >&2
		exit 1
	fi
}

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "jd-ax6600-wifi" \
	--fw "fw3" \
	--output "$FW3_OUT" >/dev/null

bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "jd-ax6600-wifi" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y'
grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=' "$FW3_OUT" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=n'
assert_no_active_value "$FW3_OUT" "CONFIG_PACKAGE_kmod-ath11k"
assert_no_active_value "$FW3_OUT" "CONFIG_PACKAGE_ath11k-firmware-ipq6018"
assert_no_active_value "$FW3_OUT" "CONFIG_PACKAGE_wpad-openssl"

assert_last_value "$FW3_OUT" "CONFIG_IB" "y"
assert_last_value "$FW3_OUT" "CONFIG_IB_STANDALONE" "y"
assert_last_value "$FW3_OUT" "CONFIG_PACKAGE_cpufreq" "m"
assert_last_value "$FW3_OUT" "CONFIG_PACKAGE_kmod-dsa-tag-dsa" "y"
assert_last_value "$FW3_OUT" "CONFIG_PACKAGE_kmod-sched-act-ipt" "y"

assert_last_value "$FW4_OUT" "CONFIG_PACKAGE_firewall4" "y"
assert_last_value "$FW4_OUT" "CONFIG_PACKAGE_firewall" "n"
assert_last_value "$FW4_OUT" "CONFIG_PACKAGE_iptables" "n"
assert_last_value "$FW4_OUT" "CONFIG_PACKAGE_nftables" "y"
assert_last_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-turboacc" "n"
assert_last_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-homeproxy" "y"
assert_last_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-openclash" "y"
assert_no_active_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-ssr-plus"

echo "test_jd_ax6600_wifi_export: ok"
