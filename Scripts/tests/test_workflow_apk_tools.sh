#!/bin/bash

set -eu

WORKFLOW_FILE="$(cd "$(dirname "$0")/../.." && pwd)/.github/workflows/CORE-ALL.yml"

apk_step_line=$(grep -n 'Apply apk-tools Patch' "$WORKFLOW_FILE" | cut -d: -f1 | head -n1 || true)
diy_feeds_line=$(grep -n 'DIY Feeds (自定义 Feeds)' "$WORKFLOW_FILE" | cut -d: -f1 | head -n1 || true)

test -n "$apk_step_line"
test -n "$diy_feeds_line"
test "$apk_step_line" -lt "$diy_feeds_line"

sed -n "${apk_step_line},$((apk_step_line + 5))p" "$WORKFLOW_FILE" | grep -Fq "if: env.WRT_PACKAGE_MANAGER == 'apk'"
sed -n "${apk_step_line},$((apk_step_line + 5))p" "$WORKFLOW_FILE" | grep -Fq 'apk-tools.sh'
grep -Fq '跳过 apk-tools 补丁' "$WORKFLOW_FILE"

printf '%s\n' 'test_workflow_apk_tools: ok'
