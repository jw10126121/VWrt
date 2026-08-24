#!/bin/bash

# 说明：WiFi 凭据必须由工作流统一传给 DIY 脚本，避免固件配置与说明内容不一致。

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/CORE-ALL.yml"
DIY_SCRIPT="$REPO_ROOT/Scripts/diy_config.sh"

grep -Fq '      WRT_WIFI_SSID:' "$WORKFLOW_FILE"
grep -Fq "        default: 'OpenwrtAP'" "$WORKFLOW_FILE"
grep -Fq '      WRT_WIFI_PASSWORD:' "$WORKFLOW_FILE"
grep -Fq "        default: '88886666'" "$WORKFLOW_FILE"
grep -Fq '  WRT_WIFI_SSID: ${{inputs.WRT_WIFI_SSID}}' "$WORKFLOW_FILE"
grep -Fq '  WRT_WIFI_PASSWORD: ${{inputs.WRT_WIFI_PASSWORD}}' "$WORKFLOW_FILE"
grep -Fq 'WRT_SSID="${WRT_WIFI_SSID:-OpenwrtAP}"' "$DIY_SCRIPT"
grep -Fq 'WRT_WORD="${WRT_WIFI_PASSWORD:-88886666}"' "$DIY_SCRIPT"
if grep -Fq -- '-s "${{ env.WRT_WIFI_SSID }}"' "$WORKFLOW_FILE" || \
   grep -Fq -- '-w "${{ env.WRT_WIFI_PASSWORD }}"' "$WORKFLOW_FILE"; then
    echo "Custom DIY scripts must not receive unsupported WiFi CLI options" >&2
    exit 1
fi
grep -Fq '        configure_wifi_lean' "$DIY_SCRIPT"

echo "test_core_all_wifi_credentials: ok"
