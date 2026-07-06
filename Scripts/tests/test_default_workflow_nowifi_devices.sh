#!/bin/bash

set -eu

DEFAULT_WORKFLOW=".github/workflows/DEFAULT.yml"

grep -Fq 'gl-mt6000-nowifi' "$DEFAULT_WORKFLOW" || {
	echo "DEFAULT should expose gl-mt6000-nowifi in manual device options" >&2
	exit 1
}

echo "test_default_workflow_nowifi_devices: ok"
