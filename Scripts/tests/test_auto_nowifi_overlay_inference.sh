#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
OVERLAY_UTILS="$SCRIPT_DIR/lib/overlay_utils.sh"

# shellcheck disable=SC1090
. "$OVERLAY_UTILS"

test "$(infer_default_overlays_for_device "$SCRIPT_DIR/../Config" "cmiot-ax18-nowifi" "fw3")" = "nowifi-ipq60xx"
test "$(infer_default_overlays_for_device "$SCRIPT_DIR/../Config" "jd-ax1800pro-nowifi" "fw4")" = "nowifi-ipq60xx"
test "$(infer_default_overlays_for_device "$SCRIPT_DIR/../Config" "jd-ax6600-nowifi" "fw4")" = "nowifi-ipq60xx"
test "$(infer_default_overlays_for_device "$SCRIPT_DIR/../Config" "gl-mt6000-nowifi" "fw4")" = "nowifi-filogic"
test "$(infer_default_overlays_for_device "$SCRIPT_DIR/../Config" "gl-mt6000-wifi" "fw4")" = ""

MERGED=$(merge_overlay_csv_lists "$SCRIPT_DIR/../Config" "nowifi-ipq60xx" "frps,apk")
test "$MERGED" = "nowifi-ipq60xx,frps,apk"

echo "test_auto_nowifi_overlay_inference: ok"
