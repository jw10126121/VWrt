#!/bin/bash

set -eu

WORKFLOW_FILE=".github/workflows/CORE-ALL.yml"

diy_after_line=$(grep -n '^    - name: DIY after defconfig (确认config后执行脚本)$' "$WORKFLOW_FILE" | cut -d: -f1)
read_vars_line=$(grep -nF '    - name: Read Variables (读取变量)' "$WORKFLOW_FILE" | tail -n1 | cut -d: -f1)
summary_line=$(grep -n '^    - name: Print Build Summary (打印编译条件摘要)$' "$WORKFLOW_FILE" | cut -d: -f1)

[ -n "$diy_after_line" ] || {
	echo "DIY after defconfig step should exist" >&2
	exit 1
}

[ -n "$summary_line" ] || {
	echo "Print Build Summary step should exist" >&2
	exit 1
}

if [ "$summary_line" -le "$diy_after_line" ]; then
	echo "Print Build Summary should be placed after DIY after defconfig" >&2
	exit 1
fi

[ -n "$read_vars_line" ] || {
	echo "Read Variables step should exist" >&2
	exit 1
}

if [ "$summary_line" -le "$read_vars_line" ]; then
	echo "Print Build Summary should be placed after Read Variables" >&2
	exit 1
fi

grep -Fq -- '--context-output "$EXPORT_CONTEXT_FILE"' "$WORKFLOW_FILE"
grep -Fq -- 'WRT_EXTRA_CONFIGS_FILE="$OPENWRT_PATH/.linjw-extra-configs"' "$WORKFLOW_FILE"
grep -Fq -- '【Lin】本次编译条件摘要' "$WORKFLOW_FILE"
grep -Fq -- 'device_alias_from_logical_name "$WRT_DEVICE"' "$WORKFLOW_FILE"
grep -Fq -- '【Lin】源码仓库：$WRT_REPO_URL' "$WORKFLOW_FILE"
grep -Fq -- '【Lin】源码分支：$WRT_REPO_BRANCH' "$WORKFLOW_FILE"
grep -Fq -- '【Lin】源码提交：${REPO_GIT_HASH:-未知}' "$WORKFLOW_FILE"
grep -Fq -- '【Lin】OP版本：${OP_VERSION:-未知}' "$WORKFLOW_FILE"
grep -Fq -- '【Lin】LuCI版本：${LUCI_VERSION:-未知}' "$WORKFLOW_FILE"
grep -Fq -- '【Lin】默认主题：${DEFAULT_THEME:-源码默认}' "$WORKFLOW_FILE"

if grep -Fq -- '【Lin】已编入主题：' "$WORKFLOW_FILE"; then
	echo "Build summary should not print builtin theme list" >&2
	exit 1
fi

if grep -Fq -- '【Lin】可选主题包：' "$WORKFLOW_FILE"; then
	echo "Build summary should not print optional theme list" >&2
	exit 1
fi

echo "test_core_all_build_summary: ok"
