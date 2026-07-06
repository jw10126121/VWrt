#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"

extract_function_body() {
	local fn="$1"

	awk -v name="$fn" '
		$0 ~ "^" name "\\(\\) \\{" { in_fn=1; next }
		in_fn && /^}/ { exit }
		in_fn { print }
	' "$TARGET_SCRIPT"
}

grep -q '^UPDATE_LANSPEED() {' "$TARGET_SCRIPT"

LANSPEED_BODY=$(extract_function_body "UPDATE_LANSPEED")
COMMON_BODY=$(extract_function_body "apply_common_package_overrides")

printf '%s\n' "$LANSPEED_BODY" | grep -q 'local LANSPEED_REPO="https://github.com/qimaoww/luci-app-lanspeed.git"'
printf '%s\n' "$LANSPEED_BODY" | grep -q 'rm -rf "${package_workdir}/luci-app-lanspeed" "${package_workdir}/lanspeedd"'
printf '%s\n' "$LANSPEED_BODY" | grep -q 'applications/luci-app-lanspeed/Makefile'
printf '%s\n' "$LANSPEED_BODY" | grep -q 'net/lanspeedd/Makefile'
printf '%s\n' "$COMMON_BODY" | grep -q 'UPDATE_LANSPEED'

echo "test_packages_lanspeed: ok"
