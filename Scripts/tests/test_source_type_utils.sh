#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_LIB="$SCRIPT_DIR/lib/source_type.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

# shellcheck source=/dev/null
. "$TARGET_LIB"

test "$(normalize_source_type lean)" = "lean"
test "$(normalize_source_type lwrt)" = "lean"
test "$(normalize_source_type iwrt)" = "vwrt"
test "$(normalize_source_type vwrt)" = "vwrt"
test "$(normalize_source_type libwrt)" = "libwrt"
test "$(source_config_family lean)" = "lean"
test "$(source_config_family iwrt)" = "iwrt"
test "$(source_config_family vwrt)" = "iwrt"
test "$(source_config_family libwrt)" = "iwrt"

mkdir -p "$TMPDIR/lean/package/lean/default-settings/files"
: > "$TMPDIR/lean/package/lean/default-settings/files/zzz-default-settings"
mkdir -p "$TMPDIR/vwrt/package/base-files"

test "$(detect_source_type_from_tree "$TMPDIR/lean")" = "lean"
test "$(detect_source_type_from_tree "$TMPDIR/vwrt")" = "vwrt"
test "$(resolve_source_type auto "$TMPDIR/lean")" = "lean"
test "$(resolve_source_type auto "$TMPDIR/vwrt")" = "vwrt"
test "$(resolve_source_type vwrt "$TMPDIR/vwrt")" = "vwrt"
test "$(resolve_source_type libwrt "$TMPDIR/vwrt")" = "libwrt"

echo "test_source_type_utils: ok"
