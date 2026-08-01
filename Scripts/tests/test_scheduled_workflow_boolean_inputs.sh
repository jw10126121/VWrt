#!/bin/bash

# 说明：schedule 事件没有 workflow_dispatch inputs；传给 reusable workflow 的
# WRT_RELEASE_FIRMWARE 必须始终解析为 boolean，不能在定时触发时变成空字符串。

set -euo pipefail

expected_expression='      WRT_RELEASE_FIRMWARE: ${{ github.event_name == '\''workflow_dispatch'\'' && inputs.WRT_RELEASE_FIRMWARE }}'
unsafe_expression='      WRT_RELEASE_FIRMWARE: ${{ inputs.WRT_RELEASE_FIRMWARE }}'

assert_scheduled_boolean_inputs() {
	local workflow="$1"
	local expected_jobs="$2"
	local actual_jobs

	actual_jobs=$(grep -Fc "$expected_expression" "$workflow" || true)
	if [ "$actual_jobs" -ne "$expected_jobs" ]; then
		echo "ASSERT FAILED: ${workflow} should pass an explicit boolean for all ${expected_jobs} scheduled jobs" >&2
		echo "Expected expression count: ${expected_jobs}; actual: ${actual_jobs}" >&2
		exit 1
	fi

	if grep -Fq "$unsafe_expression" "$workflow"; then
		echo "ASSERT FAILED: ${workflow} should not pass a possibly empty dispatch input to a boolean reusable-workflow input" >&2
		exit 1
	fi
}

assert_scheduled_boolean_inputs ".github/workflows/CUSTOM-LWRT.yml" 3
assert_scheduled_boolean_inputs ".github/workflows/CUSTOM-iwrt.yml" 3
assert_scheduled_boolean_inputs ".github/workflows/ForCache.yml" 4

echo "test_scheduled_workflow_boolean_inputs: ok"
