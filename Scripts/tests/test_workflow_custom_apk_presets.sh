#!/bin/bash

# 说明：验证 DEFAULT reusable workflow 暴露结构化 FRP/USB 输入，
# 自身只做解析与透传，不再本地合成最终 overlays。

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
assert_contains "$default_workflow" 'usb_label: ${{ steps.resolve.outputs.usb_label }}' "DEFAULT resolve job should expose a normalized USB label"
assert_contains "$default_workflow" "format('-{0}', inputs.WRT_OVERLAYS)" "DEFAULT run name should append manual overlays only when present"
assert_contains "$default_workflow" 'run-name: ${{ inputs.WRT_DEVICE }}-${{ inputs.SOURCE_TYPE }}-${{ inputs.WRT_FIREWALL == '"'"'auto'"'"' && (inputs.SOURCE_TYPE == '"'"'lean'"'"' && '"'"'fw3'"'"' || '"'"'fw4'"'"') || inputs.WRT_FIREWALL }}-${{ inputs.WRT_FRP_MODE }}-${{ inputs.WRT_USB_MODE == '"'"'nousb'"'"' && '"'"'nousb'"'"' || '"'"'usb'"'"' }}-${{ inputs.WRT_PACKAGE_MANAGER == '"'"'auto'"'"' && (inputs.SOURCE_TYPE == '"'"'vwrt'"'"' && '"'"'apk'"'"' || '"'"'ipk'"'"') || inputs.WRT_PACKAGE_MANAGER }}${{ inputs.WRT_OVERLAYS != '"'"''"'"' && format('"'"'-{0}'"'"', inputs.WRT_OVERLAYS) || '"'"''"'"' }}' "DEFAULT run name should use compact resolved labels"
assert_contains "$default_workflow" "WRT_LUCI_BRANCH:" "DEFAULT reusable workflow should expose LuCI branch input"
assert_contains "$default_workflow" 'frp_mode: ${{ steps.resolve.outputs.frp_mode }}' "DEFAULT resolve job should expose normalized FRP mode"
assert_contains "$default_workflow" 'usb_mode: ${{ steps.resolve.outputs.usb_mode }}' "DEFAULT resolve job should expose normalized USB mode"
assert_contains "$default_workflow" 'WRT_FRP_MODE: ${{ needs.resolve.outputs.frp_mode }}' "DEFAULT should pass normalized FRP mode to CORE-ALL"
assert_contains "$default_workflow" 'WRT_USB_MODE: ${{ needs.resolve.outputs.usb_mode }}' "DEFAULT should pass normalized USB mode to CORE-ALL"
assert_contains "$default_workflow" 'WRT_OVERLAYS: ${{ inputs.WRT_OVERLAYS }}' "DEFAULT should pass manual overlays directly to CORE-ALL"
assert_contains "$default_workflow" 'name: ${{ inputs.WRT_DEVICE }}-${{ needs.resolve.outputs.firewall }}-${{ needs.resolve.outputs.frp_mode }}-${{ needs.resolve.outputs.usb_label }}-${{ needs.resolve.outputs.package_manager }}${{ inputs.WRT_OVERLAYS != '"'"''"'"' && format('"'"'-{0}'"'"', inputs.WRT_OVERLAYS) || '"'"''"'"' }}' "DEFAULT config job name should keep structured labels while only appending manual overlays"
assert_not_contains "$default_workflow" 'append_csv "$package_manager_input"' "DEFAULT should not duplicate package-manager selection into overlays"
assert_not_contains "$default_workflow" "structured_overlays=''" "DEFAULT should not compose structured overlays locally anymore"
assert_not_contains "$default_workflow" 'overlays: ${{ steps.resolve.outputs.overlays }}' "DEFAULT should not expose a composed overlays output"
assert_not_contains "$default_workflow" 'overlay_label:' "DEFAULT should not expose overlay labels after moving composition to CORE-ALL"
assert_not_contains "$default_workflow" 'overlay_suffix:' "DEFAULT should not expose overlay suffix after moving composition to CORE-ALL"
assert_not_contains "$default_workflow" "Unsupported WRT_FRP_MODE:" "DEFAULT should not keep redundant FRP guard branches"
assert_not_contains "$default_workflow" "Unsupported WRT_USB_MODE:" "DEFAULT should not keep redundant USB guard branches"
assert_not_contains "$default_workflow" "Unsupported WRT_PACKAGE_MANAGER:" "DEFAULT should not keep redundant package-manager guard branches"
assert_contains "$default_workflow" "cmiot-ax18-nowifi" "DEFAULT should expose AX18 entry in manual choices"
assert_contains "$default_workflow" "jd-ax1800pro-wifi" "DEFAULT should expose JD AX1800 Pro entry in manual choices"
assert_contains "$default_workflow" "gl-mt6000-wifi" "DEFAULT should expose MT6000 in manual choices"

assert_contains "$core_workflow" "WRT_PACKAGE_MANAGER:" "CORE-ALL should expose package-manager input"
assert_contains "$core_workflow" "WRT_FRP_MODE:" "CORE-ALL should expose FRP mode input"
assert_contains "$core_workflow" "WRT_USB_MODE:" "CORE-ALL should expose USB mode input"
assert_not_contains "$core_workflow" "WRT_USE_APK:" "CORE-ALL should no longer expose the legacy boolean package-manager input"
assert_not_contains "$core_workflow" 'WRT_USE_APK="${{ inputs.WRT_USE_APK }}"' "CORE-ALL should not resolve package manager from a boolean-style input"
assert_not_contains "$core_workflow" "WRT_USE_APK=true" "CORE-ALL should not keep boolean true package-manager assignments"
assert_not_contains "$core_workflow" "WRT_USE_APK=false" "CORE-ALL should not keep boolean false package-manager assignments"
assert_not_contains "$core_workflow" "env.WRT_USE_APK == 'true' && 'apk' || 'ipk'" "CORE-ALL should pass apk/ipk directly to diy_config"

echo "test_workflow_custom_apk_presets: ok"
