#!/bin/bash

set -eu

WORKFLOW_FILE=".github/workflows/CORE-ALL.yml"

diy_after_line=$(grep -n '^    - name: DIY after defconfig (确认config后执行脚本)$' "$WORKFLOW_FILE" | cut -d: -f1)
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

grep -Fq -- '--context-output "$EXPORT_CONTEXT_FILE"' "$WORKFLOW_FILE"
grep -Fq -- 'WRT_EXTRA_CONFIGS_FILE="$OPENWRT_PATH/.linjw-extra-configs"' "$WORKFLOW_FILE"
grep -Fq -- '【Lin】本次编译条件摘要' "$WORKFLOW_FILE"
grep -Fq -- 'device_alias_from_logical_name "$WRT_DEVICE"' "$WORKFLOW_FILE"

echo "test_core_all_build_summary: ok"
