#!/bin/bash

# 说明：验证默认主题 auto 会按源码类型解析，
# lean 使用 argon，非 lean 使用 aurora，并保留显式主题覆盖能力。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/sed" <<'EOF'
#!/bin/bash
set -eu

if [ $# -ge 1 ] && [ "$1" = "-i" ]; then
	shift
	exec /usr/bin/sed -i "" "$@"
fi

exec /usr/bin/sed "$@"
EOF
chmod +x "$TMPDIR/bin/sed"
PATH="$TMPDIR/bin:$PATH"
export PATH

extract_function() {
	local function_name=$1
	local function_body
	function_body=$(awk -v name="$function_name" '
		$0 ~ "^" name "\\(\\) *\\{" { printing=1 }
		printing { print }
		printing && $0 == "}" { exit }
	' "$TARGET_SCRIPT")

	if [ -z "$function_body" ]; then
		echo "Missing expected function: $function_name" >&2
		exit 1
	fi

	printf '%s\n' "$function_body"
}

FUNCTIONS_FILE="$TMPDIR/functions.sh"
{
	extract_function "set_kconfig_value"
	echo
	extract_function "resolve_default_theme"
	echo
	extract_function "configure_default_theme"
} > "$FUNCTIONS_FILE"

run_case() {
	local case_name=$1
	local source_type=$2
	local requested_theme=$3
	local expected_theme=$4
	local case_dir="$TMPDIR/$case_name"
	local config_path="$case_dir/.config"
	local collection_makefile="$case_dir/feeds/luci/collections/luci/Makefile"

	mkdir -p \
		"$case_dir/package/luci-theme-argon" \
		"$case_dir/package/luci-theme-aurora" \
		"$case_dir/package/luci-theme-noobwrt" \
		"$case_dir/feeds/luci/collections/luci" \
		"$case_dir/feeds/packages"

	cat > "$collection_makefile" <<'EOF'
LUCI_DEPENDS:=+luci-theme-bootstrap
EOF
	cat > "$config_path" <<'EOF'
CONFIG_PACKAGE_luci-theme-argon=m
CONFIG_PACKAGE_luci-theme-aurora=m
CONFIG_PACKAGE_luci-theme-noobwrt=m
EOF

	(
		cd "$case_dir"
		op_config="$config_path"
		SOURCE_TYPE="$source_type"
		WRT_THEME="$requested_theme"
		export op_config SOURCE_TYPE WRT_THEME
		# shellcheck disable=SC1090
		. "$FUNCTIONS_FILE"
		configure_default_theme >/dev/null
	)

	grep -q "luci-theme-${expected_theme}" "$collection_makefile"
	grep -q "^CONFIG_PACKAGE_luci-theme-${expected_theme}=y$" "$config_path"
}

run_case lean_auto lean auto argon
run_case vwrt_auto vwrt auto aurora
run_case libwrt_auto libwrt auto aurora
run_case explicit_theme lean noobwrt noobwrt

echo "test_diy_config_default_theme: ok"
