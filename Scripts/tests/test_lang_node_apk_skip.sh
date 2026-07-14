#!/bin/bash

# 说明：验证 Packages.sh 外层在 APK 模式下也会尝试 sbwml lang_node 预编译 helper。

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PACKAGES_SCRIPT="$SCRIPT_DIR/Packages.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

MOCK_SCRIPT_ROOT="$TMPDIR/mock-scripts"
FUNCTIONS_FILE="$TMPDIR/apply_lang_node_prebuilt_fix.sh"
MARKER_FILE="$TMPDIR/helper.called"

mkdir -p "$MOCK_SCRIPT_ROOT/lib"
cat > "$MOCK_SCRIPT_ROOT/lib/lang_node_prebuilt.sh" <<EOF
#!/bin/bash
echo "called" > "$MARKER_FILE"
exit 1
EOF
chmod +x "$MOCK_SCRIPT_ROOT/lib/lang_node_prebuilt.sh"

awk '
	/^apply_lang_node_prebuilt_fix\(\) \{/ { in_func=1 }
	in_func { print }
	in_func && /^}/ { exit }
' "$PACKAGES_SCRIPT" > "$FUNCTIONS_FILE"

# shellcheck source=/dev/null
. "$FUNCTIONS_FILE"

current_script_dir="$MOCK_SCRIPT_ROOT"
openwrt_workdir="$TMPDIR/openwrt"
mkdir -p "$openwrt_workdir"

output=$(WRT_PACKAGE_MANAGER=apk apply_lang_node_prebuilt_fix 2>&1)

printf '%s\n' "$output" | grep -Fq '【Lin】尝试使用 sbwml/feeds_packages_lang_node 加速 lang_node 编译'
printf '%s\n' "$output" | grep -Fq '【Lin】未命中可用的 sbwml lang_node 预编译分支，继续使用官方 lang/node'
[ -f "$MARKER_FILE" ] || {
	echo "APK mode should invoke the sbwml lang_node helper" >&2
	exit 1
}

echo "test_lang_node_apk_skip: ok"
