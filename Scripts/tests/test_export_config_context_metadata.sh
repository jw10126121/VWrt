#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

META_OUT="$TMPDIR/context.env"
CONFIG_OUT="$TMPDIR/out.txt"

SOURCE_TYPE=vwrt bash "$EXPORT_SCRIPT" \
	--config-dir "$SCRIPT_DIR/../Config" \
	--device "jd-ax1800pro-nowifi" \
	--fw "fw4" \
	--output "$CONFIG_OUT" \
	--context-output "$META_OUT" >/dev/null

grep -qx 'RESOLVED_DEVICE_CONFIG=jd-ax1800pro-wifi-fw4-iwrt.txt' "$META_OUT"
grep -qx 'RESOLVED_DEVICE_CONFIG_PATH=Config/jd-ax1800pro-wifi-fw4-iwrt.txt' "$META_OUT"
grep -qx 'RESOLVED_GENERAL_CONFIGS=general-iwrt.txt' "$META_OUT"
grep -qx 'RESOLVED_GENERAL_CONFIG_PATHS=Config/general-iwrt.txt' "$META_OUT"
grep -qx 'RESOLVED_AUTO_OVERLAYS=nowifi-ipq60xx' "$META_OUT"
grep -qx 'RESOLVED_FINAL_OVERLAYS=nowifi-ipq60xx' "$META_OUT"
grep -qx 'RESOLVED_FINAL_OVERLAY_FILES=Config/overlays/nowifi-ipq60xx.txt' "$META_OUT"

echo "test_export_config_context_metadata: ok"
