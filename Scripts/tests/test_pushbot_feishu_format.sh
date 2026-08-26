#!/bin/bash

# 说明：PushBot 的 Feishu 格式修补必须只作用于 Feishu API 模板。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"

grep -Fq 'pushbot_feishu_file="${pushbot_dir}/root/usr/bin/pushbot/api/feishu.json"' "$TARGET_SCRIPT"
grep -Fq 'sed -i '\''s/"str_splitline": "\\\\n\\\\n"/"str_splitline": "\\\\n"/'\'' "${pushbot_feishu_file}"' "$TARGET_SCRIPT"

echo "test_pushbot_feishu_format: ok"
