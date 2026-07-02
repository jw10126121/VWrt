#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

assert_ax1800pro_fw4_profile() {
	local device="$1"
	local out_file="$TMPDIR/${device}.txt"

	bash "$EXPORT_SCRIPT" \
		--config-dir "$SCRIPT_DIR/../Config" \
		--device "$device" \
		--fw "fw4" \
		--output "$out_file" >/dev/null

	grep -n '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=' "$out_file" | tail -n 1 | grep -q 'CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y'

	if grep -q '^CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-01=y$' "$out_file"; then
		echo "Unexpected jdcloud_re-cs-01 profile in $device fw4 export" >&2
		exit 1
	fi
}

assert_ax1800pro_fw4_profile "jd-ax1800pro-wifi"
assert_ax1800pro_fw4_profile "jd-ax1800pro-nowifi"

grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$TMPDIR/jd-ax1800pro-nowifi.txt" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=n'

echo "test_jd_ax1800pro_fw4_profile: ok"
