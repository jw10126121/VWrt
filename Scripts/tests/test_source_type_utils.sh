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
test "$(normalize_source_type iwrt)" = "vikingyfy"
test "$(normalize_source_type vikingyfy)" = "vikingyfy"
test "$(normalize_source_type libwrt)" = "libwrt"
test "$(source_config_family lean)" = "lean"
test "$(source_config_family iwrt)" = "iwrt"
test "$(source_config_family vikingyfy)" = "iwrt"
test "$(source_config_family libwrt)" = "iwrt"

if normalize_source_type unsupported >/dev/null 2>&1; then
	echo "unsupported source types should fail" >&2
	exit 1
fi

mkdir -p "$TMPDIR/lean/package/lean/default-settings/files"
: > "$TMPDIR/lean/package/lean/default-settings/files/zzz-default-settings"
mkdir -p "$TMPDIR/vikingyfy/package/base-files"

test "$(detect_source_type_from_tree "$TMPDIR/lean")" = "lean"
test "$(detect_source_type_from_tree "$TMPDIR/vikingyfy")" = "vikingyfy"
test "$(resolve_source_type auto "$TMPDIR/lean")" = "lean"
test "$(resolve_source_type auto "$TMPDIR/vikingyfy")" = "vikingyfy"
test "$(resolve_source_type vikingyfy "$TMPDIR/vikingyfy")" = "vikingyfy"
test "$(resolve_source_type libwrt "$TMPDIR/vikingyfy")" = "libwrt"

echo "test_source_type_utils: ok"
