#!/bin/bash

set -eu

DEFAULT_WORKFLOW=".github/workflows/DEFAULT.yml"
CORE_WORKFLOW=".github/workflows/CORE-ALL.yml"

assert_contains() {
	local file_path=$1
	local pattern=$2
	local message=$3

	if ! grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: $message" >&2
		echo "Missing pattern: $pattern" >&2
		exit 1
	fi
}

assert_contains "$DEFAULT_WORKFLOW" "WRT_EXTRA_CONFIGS:" "DEFAULT should expose extra config input"
assert_contains "$DEFAULT_WORKFLOW" "临时附加配置" "DEFAULT manual dispatch should describe extra configs"
assert_contains "$DEFAULT_WORKFLOW" 'WRT_EXTRA_CONFIGS: ${{ inputs.WRT_EXTRA_CONFIGS }}' "DEFAULT should pass extra configs through to CORE-ALL"
assert_contains "$CORE_WORKFLOW" "WRT_EXTRA_CONFIGS:" "CORE-ALL reusable workflow should accept extra configs"
assert_contains "$CORE_WORKFLOW" "WRT_EXTRA_CONFIGS: \${{inputs.WRT_EXTRA_CONFIGS || '' }}" "CORE-ALL env should expose extra configs"

echo "test_default_workflow_extra_configs: ok"
