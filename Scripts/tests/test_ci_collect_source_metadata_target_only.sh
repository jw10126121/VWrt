#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/ci_collect_source_metadata.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
mkdir -p "$OPENWRT_PATH/target/linux/mediatek" "$OPENWRT_PATH/include"

cat > "$OPENWRT_PATH/.config" <<'EOF'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
EOF

cat > "$OPENWRT_PATH/target/linux/mediatek/Makefile" <<'EOF'
KERNEL_PATCHVER:=6.18
EOF

cat > "$OPENWRT_PATH/include/kernel-6.18" <<'EOF'
LINUX_KERNEL_HASH-6.18.35:=dummy
EOF

OPENWRT_PATH="$OPENWRT_PATH" \
WRT_REPO_URL="https://github.com/immortalwrt/immortalwrt" \
WRT_REPO_BRANCH="master" \
bash "$TARGET_SCRIPT" > "$TMPDIR/meta.env"

grep -q '^DEVICE_TARGET=mediatek$' "$TMPDIR/meta.env"
grep -q '^DEVICE_SUBTARGET=filogic$' "$TMPDIR/meta.env"
grep -q '^VERSION_KERNEL=6.18.35$' "$TMPDIR/meta.env"

echo "test_ci_collect_source_metadata_target_only: ok"
