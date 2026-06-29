#!/bin/bash

# 说明：CORE-ALL 默认交给 diy_config.sh 按源码类型解析主题。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
WORKFLOW="$SCRIPT_DIR/.github/workflows/CORE-ALL.yml"

grep -q "WRT_THEME_NAME: 'auto'" "$WORKFLOW"
grep -q -- '-t "${{env.WRT_THEME_NAME}}"' "$WORKFLOW"

echo "test_core_all_default_theme: ok"
