#!/bin/bash

# 说明：验证 iwrt 配置族在 WiFi 密码为 none 时，
# 会显式切换为开放网络，而不是仅仅跳过密码写入。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

TMPDIR=$(mktemp -d)
TEST_BIN="$TMPDIR/test-bin"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TEST_BIN"
cat > "$TEST_BIN/sed" <<'EOF'
#!/bin/sh

if [ "$1" = "-i" ]; then
	shift
	exec /usr/bin/sed -i '' "$@"
fi

exec /usr/bin/sed "$@"
EOF
chmod +x "$TEST_BIN/sed"

extract_function() {
	local function_name=$1
	awk -v name="$function_name" '
		$0 ~ "^" name "\\(\\) *\\{" { printing=1 }
		printing { print }
		printing && $0 == "}" { exit }
	' "$TARGET_SCRIPT"
}

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "configure_wifi_vwrt" > "$FUNCTIONS_FILE"

CASE_DIR="$TMPDIR/openwrt"
WIFI_UC="$CASE_DIR/package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
mkdir -p "$(dirname "$WIFI_UC")"
cat > "$WIFI_UC" <<'EOF'
let defaults = {
	ssid='ImmortalWrt'
	country='US'
	encryption='psk2+ccmp'
	key='oldpass'
}
EOF

(
	cd "$CASE_DIR"
	WRT_SSID='OpenAP'
	WRT_WORD='none'
	PATH="$TEST_BIN:$PATH"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	configure_wifi_vwrt >/dev/null
)

grep -q "^.*ssid='OpenAP'$" "$WIFI_UC"
grep -q "^.*country='CN'$" "$WIFI_UC"
grep -q "^.*encryption='none'$" "$WIFI_UC"
grep -q "^.*key=''$" "$WIFI_UC"

echo "test_diy_config_wifi_open_mode: ok"
