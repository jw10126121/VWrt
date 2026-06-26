#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
RESOLVE_SCRIPT="$SCRIPT_DIR/resolve_device_script.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

touch "$TMPDIR/Packages.sh"
touch "$TMPDIR/Packages-jd-ax6600.sh"
touch "$TMPDIR/Packages-gl-mt6000-wifi.sh"

result=$(bash "$RESOLVE_SCRIPT" "$TMPDIR" "auto" "jd-ax6600-wifi")
test "$result" = "Packages-jd-ax6600.sh"

result=$(bash "$RESOLVE_SCRIPT" "$TMPDIR" "auto" "gl-mt6000-wifi")
test "$result" = "Packages-gl-mt6000-wifi.sh"

result=$(bash "$RESOLVE_SCRIPT" "$TMPDIR" "auto" "cmiot-ax18-nowifi")
test "$result" = "Packages.sh"

result=$(bash "$RESOLVE_SCRIPT" "$TMPDIR" "Packages.sh" "jd-ax6600-wifi")
test "$result" = "Packages.sh"

PACKAGES_JD_AX6600_SCRIPT="$SCRIPT_DIR/Packages-jd-ax6600.sh"
grep -Fq 'bash "${script_dir}/Packages.sh"' "$PACKAGES_JD_AX6600_SCRIPT"
grep -Fq '继续执行 AX6600 专用包逻辑' "$PACKAGES_JD_AX6600_SCRIPT"

echo "test_resolve_device_script: ok"
