#!/bin/bash

# 说明：验证 DEFAULT reusable workflow 暴露了结构化 overlay 输入，
# 并由 resolve 直接产出最终 overlays 传给 CORE-ALL。

set -euo pipefail

default_workflow=".github/workflows/DEFAULT.yml"
core_workflow=".github/workflows/CORE-ALL.yml"

assert_contains() {
	local file_path="$1"
	local pattern="$2"
	local message="$3"

	if ! grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local file_path="$1"
	local pattern="$2"
	local message="$3"

	if grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains "$default_workflow" "workflow_call:" "DEFAULT should be reusable from CUSTOM-APK"
assert_contains "$default_workflow" "WRT_OVERLAYS:" "DEFAULT reusable workflow should expose overlays input"
assert_contains "$default_workflow" "WRT_FRP_MODE:" "DEFAULT should expose FRP mode input"
assert_contains "$default_workflow" "WRT_USB_MODE:" "DEFAULT should expose USB mode input"
assert_contains "$default_workflow" "WRT_PACKAGE_MANAGER:" "DEFAULT should expose package manager input"
assert_not_contains "$default_workflow" "WRT_USE_APK:" "DEFAULT should no longer expose the legacy boolean package-manager input"
assert_contains "$default_workflow" "default: 'frpc'" "DEFAULT should default FRP mode to frpc"
assert_contains "$default_workflow" "          - frp" "DEFAULT should expose the combined frp mode option"
assert_contains "$default_workflow" "WRT_LUCI_BRANCH:" "DEFAULT reusable workflow should expose LuCI branch input"
assert_contains "$default_workflow" 'overlays: ${{ steps.resolve.outputs.overlays }}' "DEFAULT resolve job should expose composed overlays"
assert_contains "$default_workflow" 'overlay_label: ${{ steps.resolve.outputs.overlay_label }}' "DEFAULT resolve job should expose overlay label"
assert_contains "$default_workflow" 'WRT_OVERLAYS: ${{ needs.resolve.outputs.overlays }}' "DEFAULT should pass resolve overlays to CORE-ALL"
assert_contains "$default_workflow" "structured_overlays=''" "DEFAULT should build structured overlays as a direct CSV string"
assert_contains "$default_workflow" 'if [ "$frp_mode" = "frpc" ] || [ "$frp_mode" = "frps" ] || [ "$frp_mode" = "frp" ]; then' "DEFAULT should append FRP overlays from frpc/frps/frp values"
assert_contains "$default_workflow" 'if [ "$usb_mode" = "usb" ] || [ "$usb_mode" = "nousb" ]; then' "DEFAULT should append USB overlays only from usb/nousb values"
assert_not_contains "$default_workflow" 'append_csv "$package_manager_input"' "DEFAULT should not duplicate package-manager selection into overlays"
assert_not_contains "$default_workflow" "declare -a overlays=()" "DEFAULT should not keep array-based overlay composition"
assert_not_contains "$default_workflow" "normalize_overlay_name()" "DEFAULT should not normalize overlays locally before passing to CORE-ALL"
assert_not_contains "$default_workflow" "Unsupported WRT_FRP_MODE:" "DEFAULT should not keep redundant FRP guard branches"
assert_not_contains "$default_workflow" "Unsupported WRT_USB_MODE:" "DEFAULT should not keep redundant USB guard branches"
assert_not_contains "$default_workflow" "Unsupported WRT_PACKAGE_MANAGER:" "DEFAULT should not keep redundant package-manager guard branches"
assert_contains "$default_workflow" "cmiot-ax18-nowifi" "DEFAULT should expose AX18 entry in manual choices"
assert_contains "$default_workflow" "jd-ax1800pro-wifi" "DEFAULT should expose JD AX1800 Pro entry in manual choices"
assert_contains "$default_workflow" "gl-mt6000-wifi" "DEFAULT should expose MT6000 in manual choices"

assert_contains "$core_workflow" "WRT_PACKAGE_MANAGER:" "CORE-ALL should expose package-manager input"
assert_not_contains "$core_workflow" "WRT_USE_APK:" "CORE-ALL should no longer expose the legacy boolean package-manager input"
assert_not_contains "$core_workflow" 'WRT_USE_APK="${{ inputs.WRT_USE_APK }}"' "CORE-ALL should not resolve package manager from a boolean-style input"
assert_not_contains "$core_workflow" "WRT_USE_APK=true" "CORE-ALL should not keep boolean true package-manager assignments"
assert_not_contains "$core_workflow" "WRT_USE_APK=false" "CORE-ALL should not keep boolean false package-manager assignments"
assert_not_contains "$core_workflow" "env.WRT_USE_APK == 'true' && 'apk' || 'ipk'" "CORE-ALL should pass apk/ipk directly to diy_config"

echo "test_workflow_custom_apk_presets: ok"
