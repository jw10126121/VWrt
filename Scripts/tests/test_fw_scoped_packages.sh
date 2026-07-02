#!/bin/bash

# 说明：验证只允许在特定防火墙栈下启用的包，最终合并结果符合预期。

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

assert_last_config_value "$FW3_OUT" "CONFIG_PACKAGE_luci-app-turboacc" "y"
assert_last_config_value "$FW3_OUT" "CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn" "y"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_luci-app-turboacc" "n"
assert_last_config_value "$FW4_OUT" "CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn" "n"

echo "test_fw_scoped_packages: ok"
