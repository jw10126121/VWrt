#!/bin/bash
set -euo pipefail

kconfig="${1:?需要提供 OpenWrt 源码目录}/config/Config-build.in"
if [ ! -f "$kconfig" ]; then
    printf '【Lin】找不到上游 Kconfig：%s，请显式指定 apk 或 ipk\n' "$kconfig" >&2
    exit 1
fi

if ! package_manager=$(awk '
    /^[[:space:]]*(config|menuconfig)[[:space:]]+USE_APK([[:space:]]|$)/ { in_symbol=1; next }
    in_symbol && /^[[:space:]]*(config|menuconfig|menu|endmenu|if|endif|choice|endchoice|comment|source|help)([[:space:]]|$)/ { exit }
    in_symbol {
        sub(/[[:space:]]*#.*/, "")
        if ($1 == "depends" || $1 == "visible") unsupported=1
        if (!seen_default && ($1 == "default" || $1 == "def_bool")) {
            seen_default=1
            if (NF == 2 && ($2 == "y" || $2 == "n")) enabled=($2 == "y")
            else unsupported=1
        }
    }
    END {
        if (unsupported) exit 1
        print (enabled ? "apk" : "ipk")
    }
' "$kconfig"); then
    printf '【Lin】无法从 %s 确定 USE_APK 默认值，请显式指定 apk 或 ipk\n' "$kconfig" >&2
    exit 1
fi

printf '%s\n' "$package_manager"
