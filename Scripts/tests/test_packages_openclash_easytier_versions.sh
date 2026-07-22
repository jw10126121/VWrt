#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"

extract_function() {
	local fn="$1"

	awk -v name="$fn" '
		$0 ~ "^" name "\\(\\) \\{" { printing=1 }
		printing { print }
		printing && /^}/ { exit }
	' "$TARGET_SCRIPT"
}

COMMON_BODY=$(awk '
	/^apply_common_package_overrides\(\) \{/ { printing=1; next }
	printing && /^}/ { exit }
	printing { print }
' "$TARGET_SCRIPT")

POST_FIX_BODY=$(awk '
	/^apply_post_update_fixes\(\) \{/ { printing=1; next }
	printing && /^}/ { exit }
	printing { print }
' "$TARGET_SCRIPT")

printf '%s\n' "$COMMON_BODY" | grep -q 'UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "master" "pkg"'
printf '%s\n' "$COMMON_BODY" | grep -q '^    prepare_ninjaconnector2_package$'
grep -q '^prepare_ninjaconnector2_package() {$' "$TARGET_SCRIPT"
grep -q 'local package_file="${package_name}_${package_version}-${package_release}_all.ipk"' "$TARGET_SCRIPT"
grep -q 'PKG_VERSION:=${package_version}' "$TARGET_SCRIPT"
grep -q 'PKG_RELEASE:=${package_release}' "$TARGET_SCRIPT"
grep -q '067872b03de0f5fc214fc1c5ea840502a93faa8b1f44454230661b3d677eb315' "$TARGET_SCRIPT"

if printf '%s\n' "$COMMON_BODY" | grep -q 'UPDATE_PACKAGE "luci-app-openclash" "vernesong/OpenClash" "dev" "pkg"'; then
	echo "OpenClash override should no longer track the dev branch" >&2
	exit 1
fi

printf '%s\n' "$COMMON_BODY" | grep -q 'pin_easytier_binary_version'
printf '%s\n' "$COMMON_BODY" | grep -q 'update_package_list "luci-app-easytier easytier easytier-noweb" "EasyTier/luci-app-easytier" "v2.6.4"'
if printf '%s\n' "$POST_FIX_BODY" | grep -q 'preload_homeproxy_resources'; then
	echo "Packages.sh should not preload HomeProxy resources in the default post-update fix chain" >&2
	exit 1
fi

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "pin_easytier_binary_version" > "$FUNCTIONS_FILE"

TEST_REPO="$TMPDIR/package"
mkdir -p "$TEST_REPO/easytier" "$TEST_REPO/easytier-noweb" "$TEST_REPO/luci-app-easytier"
cat > "$TEST_REPO/easytier/Makefile" <<'EOF'
PKG_VERSION:=$(or $(EASYTIER_VERSION),2.6.2)
EOF
cat > "$TEST_REPO/easytier-noweb/Makefile" <<'EOF'
PKG_VERSION:=$(or $(EASYTIER_VERSION),2.6.2)
EOF
cat > "$TEST_REPO/luci-app-easytier/Makefile" <<'EOF'
PKG_VERSION:=$(or $(EASYTIER_VERSION),2.6.2)
EOF

# shellcheck disable=SC1090
. "$FUNCTIONS_FILE"
pin_easytier_binary_version "$TEST_REPO"

grep -q '2.6.2' "$TEST_REPO/easytier/Makefile"
grep -q '2.6.2' "$TEST_REPO/easytier-noweb/Makefile"
grep -q '2.6.2' "$TEST_REPO/luci-app-easytier/Makefile"

pin_easytier_binary_version "$TEST_REPO" "2.6.4"

grep -q '^PKG_VERSION:=2.6.4$' "$TEST_REPO/easytier/Makefile"
grep -q '^PKG_VERSION:=2.6.4$' "$TEST_REPO/easytier-noweb/Makefile"
grep -Fxq 'PKG_VERSION:=$(or $(EASYTIER_VERSION),2.6.2)' "$TEST_REPO/luci-app-easytier/Makefile"

for config_file in \
	"$SCRIPT_DIR/../Config/cmiot-ax18-wifi-fw3.txt" \
	"$SCRIPT_DIR/../Config/jd-ax1800pro-wifi-fw3.txt" \
	"$SCRIPT_DIR/../Config/gl-mt6000-wifi-fw3.txt"
do
	grep -q 'CONFIG_PACKAGE_easytier-noweb=y\|^# CONFIG_PACKAGE_easytier-noweb is not set$' "$config_file"
	! grep -q '^CONFIG_PACKAGE_easytier=y$' "$config_file"
	! grep -q '^# CONFIG_EASYTIER_INCLUDE_WEBCONSOLE is not set$' "$config_file"
done

for config_file in "$SCRIPT_DIR"/../Config/*.txt; do
	case "$(basename "$config_file")" in
		jd-ax6600-wifi-fw3.txt|jd-ax6600-wifi-fw4-iwrt.txt)
			grep -q '^CONFIG_PACKAGE_luci-app-ninjaconnector2=y' "$config_file"
			;;
		*)
			if grep -q '^CONFIG_PACKAGE_luci-app-ninjaconnector2=' "$config_file"; then
				echo "luci-app-ninjaconnector2 should only be enabled for jd-ax6600 configs: $config_file" >&2
				exit 1
			fi
			;;
	esac
done

echo "test_packages_openclash_easytier_versions: ok"
