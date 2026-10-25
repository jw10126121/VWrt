#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/apk-tools.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

OPENWRT_PATH="$TMPDIR/openwrt"
PATCH_FILE="$OPENWRT_PATH/package/system/apk/patches/0101-allow-untrusted-by-default.patch"

mkdir -p "$OPENWRT_PATH/package/system/apk"
bash -n "$TARGET_SCRIPT"
OPENWRT_PATH="$OPENWRT_PATH" bash "$TARGET_SCRIPT"

test -f "$PATCH_FILE"
grep -Fq 'ac->trust.allow_untrusted = 1;' "$PATCH_FILE"
grep -Fq '+	ac->trust.allow_untrusted = 1;' "$PATCH_FILE"
if grep -Eq '^[[:space:]]*if \(ac->flags & APK_ALLOW_UNTRUSTED\)' "$PATCH_FILE"; then
	printf '%s\n' 'patch still contains active conditional trust handling' >&2
	exit 1
fi

cp "$PATCH_FILE" "$TMPDIR/patch.before"
OPENWRT_PATH="$OPENWRT_PATH" bash "$TARGET_SCRIPT"
cmp -s "$TMPDIR/patch.before" "$PATCH_FILE"

printf '%s\n' 'test_apk_tools: ok'
