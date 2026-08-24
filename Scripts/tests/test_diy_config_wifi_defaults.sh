#!/bin/bash

# 说明：验证 diy_config.sh 的默认 WiFi 名称和密码已被正确设置。

set -eu

TARGET_SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/diy_config.sh"

grep -Fq 'WRT_SSID="${WRT_WIFI_SSID:-OpenwrtAP}"' "$TARGET_SCRIPT"
grep -Fq 'WRT_WORD="${WRT_WIFI_PASSWORD:-88886666}"' "$TARGET_SCRIPT"
grep -Fq '        configure_wifi_lean' "$TARGET_SCRIPT"

echo "test_diy_config_wifi_defaults: ok"
