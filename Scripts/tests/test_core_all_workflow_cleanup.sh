#!/bin/bash

# 说明：验证 CORE-ALL.yml 已移除确定无用的 env 定义与过期注释，
# 并收紧了可直接依赖 input 默认值的重复 env 兜底写法。

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
WORKFLOW="$SCRIPT_DIR/.github/workflows/CORE-ALL.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq -- "$pattern" "$WORKFLOW"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq -- "$pattern" "$WORKFLOW"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains "# WRT_REPO_INFO:" "CORE-ALL should remove stale commented workflow_call inputs"
assert_not_contains "# WRT_REPO_URL:" "CORE-ALL should remove stale commented repository input stubs"
assert_not_contains "# WRT_REPO_BRANCH:" "CORE-ALL should remove stale commented branch input stubs"
assert_not_contains "# - name: Initialization Environment (初始化环境)" "CORE-ALL should remove the stale initialization comment block"
assert_not_contains "# - name: ln mnt (合并磁盘mnt)" "CORE-ALL should remove the stale disk-link comment block"
assert_not_contains "# - name: Cache Toolchain (缓存工具链)" "CORE-ALL should remove the stale cachewrtbuild comment block"
assert_not_contains "#   **This is OpenWrt Firmware for" "CORE-ALL should remove the stale release body comment block"
assert_not_contains "change_branceh" "CORE-ALL should fix the old fallback-branch typo"
assert_not_contains '# WRT_REPO_URL="https://github.com/VIKINGYFY/immortalwrt"' "CORE-ALL should remove obsolete fallback repository comments"
assert_not_contains '# WRT_REPO_BRANCH="owrt"' "CORE-ALL should remove obsolete fallback branch comments"
assert_not_contains "name:  CORE-ALL" "CORE-ALL workflow name should not keep double spacing"
assert_not_contains "- name: config git (修改git下载缓冲大小)" "CORE-ALL should remove the old lowercase git step name"
assert_not_contains "- name: Clone Openwrt Code (克隆openwrt代码)" "CORE-ALL should remove the old Openwrt clone step name"
assert_not_contains "- name: diy Feeds (自定义feeds)" "CORE-ALL should remove the old DIY feeds step name"
assert_not_contains "- name: diy Packages (自定义包)" "CORE-ALL should remove the old DIY packages step name"
assert_not_contains "- name: diy config (自定义配置)" "CORE-ALL should remove the old DIY config step name"
assert_not_contains "- name: diy settings (加载自定义设置) " "CORE-ALL should remove the old DIY settings step name with trailing space"
assert_not_contains "- name: defconfig (确认配置)" "CORE-ALL should remove the old lowercase defconfig step name"
assert_not_contains "- name: Download tools (下载工具包) " "CORE-ALL should remove the old download-tools step name with trailing space"
assert_not_contains "- name: 编译固件 Build firmware" "CORE-ALL should remove the mixed-language build step name"
assert_not_contains "- name: Organize Files(整理编译后的文件)" "CORE-ALL should remove the spacing-less organize-files step name"
assert_not_contains "- name: Upload Firmware To Artifact(将固件上传到Artifact)" "CORE-ALL should remove the spacing-less firmware upload step name"
assert_not_contains "- name: Upload Packages To Artifact(将Packages包单独上传到Artifact)" "CORE-ALL should remove the spacing-less packages upload step name"
assert_not_contains "- name: Send dingding notify" "CORE-ALL should remove the old lowercase DingTalk start-notify step name"
assert_not_contains "- name: Send feishu notify (飞书开始推送)" "CORE-ALL should remove the old lowercase Feishu start-notify step name"
assert_not_contains "- name: Send dingding notify (推送编译结果消息)" "CORE-ALL should remove the old lowercase DingTalk finish-notify step name"
assert_not_contains "- name: Send feishu notify (推送编译结果消息)" "CORE-ALL should remove the old lowercase Feishu finish-notify step name"
assert_contains "name: CORE-ALL" "CORE-ALL workflow name should use normalized spacing"
assert_contains "- name: Configure Git (调整 Git 下载参数)" "CORE-ALL should use the normalized git step name"
assert_contains "- name: Clone OpenWrt Source (克隆 OpenWrt 源码)" "CORE-ALL should use the normalized clone step name"
assert_contains "- name: DIY Feeds (自定义 Feeds)" "CORE-ALL should use the normalized DIY feeds step name"
assert_contains "- name: DIY Packages (自定义包)" "CORE-ALL should use the normalized DIY packages step name"
assert_contains "- name: DIY Config (导出基础配置)" "CORE-ALL should use the normalized DIY config step name"
assert_contains "- name: DIY Settings (加载自定义设置)" "CORE-ALL should use the normalized DIY settings step name"
assert_contains "- name: Defconfig (确认配置)" "CORE-ALL should use the normalized defconfig step name"
assert_contains "- name: Download Tools (下载工具包)" "CORE-ALL should use the normalized download step name"
assert_contains "- name: Build Firmware (编译固件)" "CORE-ALL should use the normalized build step name"
assert_contains "- name: Organize Files (整理编译后的文件)" "CORE-ALL should use the normalized organize step name"
assert_contains "- name: Upload Firmware To Artifact (将固件上传到 Artifact)" "CORE-ALL should use the normalized firmware upload step name"
assert_contains "- name: Upload Packages To Artifact (将 Packages 包单独上传到 Artifact)" "CORE-ALL should use the normalized packages upload step name"
assert_contains "- name: Send DingTalk Start Notification (发送钉钉开始通知)" "CORE-ALL should use the normalized DingTalk start notification step name"
assert_contains "- name: Send Feishu Start Notification (发送飞书开始通知)" "CORE-ALL should use the normalized Feishu start notification step name"
assert_contains "- name: Send DingTalk Result Notification (发送钉钉结果通知)" "CORE-ALL should use the normalized DingTalk result notification step name"
assert_contains "- name: Send Feishu Result Notification (发送飞书结果通知)" "CORE-ALL should use the normalized Feishu result notification step name"

assert_not_contains "WRT_diy_after_defconfig:" "CORE-ALL should remove the unused diy-after-defconfig env placeholder"
assert_not_contains "UPLOAD_ALL_BIN_DIR:" "CORE-ALL should remove the unused upload-all-bin env flag"
assert_not_contains "CLASH_KERNEL:" "CORE-ALL should remove the unused clash-kernel env flag"
assert_not_contains "UPLOAD_BIN_DIR_FORCE:" "CORE-ALL should remove the unused force-upload env flag"
assert_not_contains "WRT_CONFIG_LABEL: ''" "CORE-ALL should remove the empty WRT_CONFIG_LABEL placeholder"
assert_not_contains "DEVICE_TARGET: ''" "CORE-ALL should remove the empty DEVICE_TARGET placeholder"
assert_not_contains "DEVICE_SUBTARGET: ''" "CORE-ALL should remove the empty DEVICE_SUBTARGET placeholder"
assert_not_contains "DEVICE_PROFILE: ''" "CORE-ALL should remove the empty DEVICE_PROFILE placeholder"
assert_not_contains "DEVICE_NAME_LIST: ''" "CORE-ALL should remove the empty DEVICE_NAME_LIST placeholder"
assert_not_contains "DEVICE_NAME_LIST_LIAN: ''" "CORE-ALL should remove the empty DEVICE_NAME_LIST_LIAN placeholder"
assert_not_contains "DEVICE_ARCH: ''" "CORE-ALL should remove the empty DEVICE_ARCH placeholder"
assert_not_contains "REPO_GIT_HASH: ''" "CORE-ALL should remove the empty REPO_GIT_HASH placeholder"
assert_not_contains "REPO_GIT_hash_simple: ''" "CORE-ALL should remove the empty REPO_GIT_hash_simple placeholder"
assert_not_contains "system_content: ''" "CORE-ALL should remove the empty system_content placeholder"
assert_not_contains "release_desc_file: ''" "CORE-ALL should remove the empty release_desc_file placeholder"

assert_not_contains "SOURCE_TYPE: \${{inputs.SOURCE_TYPE || 'auto'}}" "CORE-ALL should rely on the input default for SOURCE_TYPE"
assert_not_contains "WRT_DIY_FEEDS: \${{ inputs.WRT_DIY_FEEDS || 'diy_feeds.sh' }}" "CORE-ALL should rely on the input default for WRT_DIY_FEEDS"
assert_contains 'SOURCE_TYPE: ${{inputs.SOURCE_TYPE}}' "CORE-ALL should keep a direct SOURCE_TYPE env mapping"
assert_contains 'WRT_DIY_FEEDS: ${{ inputs.WRT_DIY_FEEDS }}' "CORE-ALL should keep a direct DIY feeds env mapping"

echo "test_core_all_workflow_cleanup: ok"
