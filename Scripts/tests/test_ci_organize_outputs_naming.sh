#!/bin/bash

# 说明：整理后的上传文件名应带源码风味、FW 类型和 FRP 类型，便于快速区分配置。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/ci_organize_outputs.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
mkdir -p "$OPENWRT_PATH/bin/packages" "$OPENWRT_PATH/bin/targets/qualcommax/ipq60xx"
cat > "$OPENWRT_PATH/.config" <<'EOF'
CONFIG_PACKAGE_luci-app-accesscontrol=y
EOF

cat > "$OPENWRT_PATH/my_config.txt" <<'EOF'
CONFIG_TEST=y
EOF

touch "$OPENWRT_PATH/bin/targets/qualcommax/ipq60xx/openwrt-qualcommax-ipq60xx-cmiot_ax18-squashfs-sysupgrade.bin"
touch "$OPENWRT_PATH/bin/packages/luci-app-accesscontrol_1.0.0_all.apk"

GITHUB_WORKSPACE="$TMPDIR/workspace"
mkdir -p "$GITHUB_WORKSPACE"
cp -R "$SCRIPT_DIR" "$GITHUB_WORKSPACE/Scripts"
GITHUB_ENV="$TMPDIR/github_env.txt"
GITHUB_OUTPUT="$TMPDIR/github_output.txt"
: > "$GITHUB_ENV"
: > "$GITHUB_OUTPUT"

OPENWRT_PATH="$OPENWRT_PATH" \
GITHUB_WORKSPACE="$GITHUB_WORKSPACE" \
GITHUB_ENV="$GITHUB_ENV" \
GITHUB_OUTPUT="$GITHUB_OUTPUT" \
WRT_DIR_SCRIPTS="Scripts" \
WRT_MINE_SAY="" \
system_content="支持设备：cmiot_ax18" \
SOURCE_FLAVOR_TAG="lean" \
FW_STACK_TAG="fw3" \
FRP_ROLE_TAG="frpc" \
BUILD_VARIANT_TAG="lean_fw3_ipk_frpc" \
OUTPUT_NAME_PREFIX="lean_cmiot_ax18_nowifi_fw3_ipk_frpc_D260419_T120000" \
DEVICE_SUBTARGET="ipq60xx" \
DEVICE_NAME_LIST="cmiot_ax18" \
DEVICE_NAME_LIST_LIAN="cmiot_ax18" \
WRT_VER="lede-master" \
START_TIME="D260419_T120000" \
bash "$TARGET_SCRIPT" >/dev/null

test -f "$OPENWRT_PATH/upload/config_lean_cmiot_ax18_nowifi_fw3_ipk_frpc_D260419_T120000.txt"
test -f "$OPENWRT_PATH/upload/readme_lean_cmiot_ax18_nowifi_fw3_ipk_frpc_D260419_T120000.txt"
PACKAGES_DIR="$OPENWRT_PATH/upload/lean_cmiot_ax18_nowifi_fw3_ipk_frpc_D260419_T120000_Packages"
PACKAGES_ZIP="$OPENWRT_PATH/upload/lean_cmiot_ax18_nowifi_fw3_ipk_frpc_D260419_T120000_Packages.zip"
test -d "$PACKAGES_DIR"
test -f "$PACKAGES_DIR/luci-app-accesscontrol_1.0.0_all.apk"
test -f "$PACKAGES_ZIP"
unzip -Z1 "$PACKAGES_ZIP" | grep -q '^lean_cmiot_ax18_nowifi_fw3_ipk_frpc_D260419_T120000_Packages/'
if unzip -Z1 "$PACKAGES_ZIP" | grep -q '\.tar\.gz$'; then
	echo "Packages release archive must not contain a nested tarball" >&2
	exit 1
fi
test -f "$OPENWRT_PATH/upload/lean_cmiot_ax18_nowifi_fw3_ipk_frpc_D260419_T120000_squashfs-sysupgrade.bin"
test -f "$OPENWRT_PATH/config_mine/readme.txt"
grep -q "^readme_desc_file=$OPENWRT_PATH/config_mine/readme.txt$" "$GITHUB_ENV"
grep -q "^release_desc_file=$OPENWRT_PATH/readme_release.txt$" "$GITHUB_ENV"

echo "test_ci_organize_outputs_naming: ok"
