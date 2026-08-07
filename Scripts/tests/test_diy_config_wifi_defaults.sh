#!/bin/bash

# 说明：验证 diy_config.sh 的默认 WiFi 名称和密码已被正确设置。

set -eu

TARGET_SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/diy_config.sh"

grep -Fq "WRT_SSID='LinWifi'" "$TARGET_SCRIPT"
grep -Fq "WRT_WORD='88886666'" "$TARGET_SCRIPT"

echo "test_diy_config_wifi_defaults: ok"
