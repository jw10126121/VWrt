#!/bin/bash

# 说明：带 WiFi 的构建说明应显示实际 SSID 和密码，NOWIFI 构建不应显示无线凭据。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
FINAL_METADATA_SCRIPT="$SCRIPT_DIR/ci_collect_final_metadata.sh"
README_SCRIPT="$SCRIPT_DIR/readme.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
mkdir -p "$OPENWRT_PATH/include"

cat > "$OPENWRT_PATH/.config" <<'EOF'
CONFIG_TARGET_ARCH_PACKAGES="aarch64_cortex-a53"
CONFIG_VERSION_NUMBER="24.10.5"
CONFIG_PKG_FORMAT=ipk
CONFIG_PACKAGE_firewall=y
CONFIG_PACKAGE_firewall4=n
CONFIG_PACKAGE_luci-app-accesscontrol=y
EOF

cat > "$OPENWRT_PATH/include/version.mk" <<'EOF'
VERSION_NUMBER:= OpenWrt, 24.10.5
EOF

cat > "$OPENWRT_PATH/feeds.conf.default" <<'EOF'
src-git luci https://github.com/openwrt/luci.git;openwrt-24.10
EOF

generate_descriptions() {
    local has_wifi=$1
    local output_prefix=$2
    local metadata_file="$TMPDIR/${output_prefix}.metadata"
    local system_content=""

    OPENWRT_PATH="$OPENWRT_PATH" \
    WRT_DEFAULT_LANIP="192.168.0.1" \
    WRT_HAS_LITE=false \
    WRT_HAS_WIFI="$has_wifi" \
    WRT_WIFI_SSID="OpenwrtAP" \
    WRT_WIFI_PASSWORD="88886666" \
    WRT_REPO_URL="https://github.com/example/openwrt" \
    WRT_REPO_BRANCH="main" \
    SOURCE_TYPE="lean" \
    DEVICE_TARGET="qualcommax" \
    DEVICE_SUBTARGET="ipq60xx" \
    DEVICE_PROFILE="cmiot_ax18" \
    WRT_DEVICE="cmiot-ax18-${has_wifi/true/wifi}" \
    VERSION_KERNEL="6.12.80" \
    REPO_GIT_HASH="test-hash" \
    START_TIME="D260824_T120000" \
    bash "$FINAL_METADATA_SCRIPT" > "$metadata_file"

    system_content=$(sed -n '/^system_content<<EOF_SYSTEM$/,/^EOF_SYSTEM$/ { /^system_content<<EOF_SYSTEM$/d; /^EOF_SYSTEM$/d; p; }' "$metadata_file")
    bash "$README_SCRIPT" -c "$OPENWRT_PATH/.config" -o "$TMPDIR/${output_prefix}.txt" -s "$system_content" -r false
    bash "$README_SCRIPT" -c "$OPENWRT_PATH/.config" -o "$TMPDIR/${output_prefix}-release.txt" -s "$system_content" -r true
}

generate_descriptions true wifi
grep -q '^WiFi 名称：OpenwrtAP$' "$TMPDIR/wifi.txt"
grep -q '^WiFi 密码：88886666$' "$TMPDIR/wifi.txt"
grep -q '^WiFi 名称：OpenwrtAP$' "$TMPDIR/wifi-release.txt"
grep -q '^WiFi 密码：88886666$' "$TMPDIR/wifi-release.txt"

generate_descriptions false nowifi
if grep -q '^WiFi 名称：' "$TMPDIR/nowifi.txt" "$TMPDIR/nowifi-release.txt"; then
    echo "NOWIFI descriptions must not include WiFi credentials" >&2
    exit 1
fi

echo "test_wifi_credentials_in_build_descriptions: ok"
