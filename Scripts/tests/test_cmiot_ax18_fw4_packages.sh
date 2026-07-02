#!/bin/bash

# 说明：验证 CMIOT-AX18-NOWIFI 在 FW4 导出下只保留兼容 FW4 的关键防火墙/代理组合。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FW4_OUT="$TMPDIR/fw4.txt"

assert_last_config_value() {
	local file=$1
	local key=$2
	local expected=$3
	local actual

	actual=$(
		grep -nE "^[#[:space:]]*${key}=" "$file" |
			tail -n 1 |
			sed -E 's/^[0-9]+://; s/^#[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]+$//' |
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
	--device "cmiot-ax18-nowifi" \
	--fw "fw4" \
	--output "$FW4_OUT" >/dev/null

assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_firewall4" "y"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_firewall" "n"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_iptables" "n"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_nftables" "y"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-openclash" "y"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-homeproxy" "y"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-turboacc" "n"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn" "n"
assert_no_active_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-adguardhome"
assert_no_active_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-ssr-plus"
assert_no_active_value "$FW4_OUT" "CONFIG_PACKAGE_luci-i18n-ssr-plus-zh-cn"

echo "test_cmiot_ax18_fw4_packages: ok"
