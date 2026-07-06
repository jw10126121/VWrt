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
mkdir -p "$OPENWRT_PATH/target/linux"

cat > "$OPENWRT_PATH/.config" <<'EOF'
CONFIG_TARGET_RANDOM_BOARD=y
EOF

OPENWRT_PATH="$OPENWRT_PATH" \
WRT_REPO_URL="https://github.com/example/openwrt" \
WRT_REPO_BRANCH="main" \
bash "$TARGET_SCRIPT" > "$TMPDIR/meta.env"

grep -q '^VERSION_KERNEL=unknown$' "$TMPDIR/meta.env"

echo "test_ci_collect_source_metadata_unknown_kernel: ok"
