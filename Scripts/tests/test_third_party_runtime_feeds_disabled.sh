#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
FEEDS_SCRIPT="$SCRIPT_DIR/diy_feeds.sh"
CONFIG_SCRIPT="$SCRIPT_DIR/diy_config.sh"
AFTER_SCRIPT="$SCRIPT_DIR/diy_after_defconfig.sh"

# 第三方仓库仍作为编译期 feed 使用。
grep -Fq 'append_feed_if_missing "miaomiaowu" "src-git miaomiaowu https://github.com/xiaohai77/OpenWrt-MMW.git"' "$FEEDS_SCRIPT"
grep -Fq 'append_feed_if_missing "istore" "src-git istore https://github.com/linkease/istore;main"' "$FEEDS_SCRIPT"

# 但不生成 APK/IPK 运行时软件源。
grep -Fq '    set_kconfig_value "CONFIG_FEED_miaomiaowu" "n"' "$CONFIG_SCRIPT" || {
	echo "diy_config.sh must disable the miaomiaowu runtime feed" >&2
	exit 1
}
grep -Fq '    set_kconfig_value "CONFIG_FEED_istore" "n"' "$CONFIG_SCRIPT" || {
	echo "diy_config.sh must disable the iStore runtime feed" >&2
	exit 1
}

if grep -Fq 'configure_third_party_apk_feeds' "$AFTER_SCRIPT"; then
	echo "diy_after_defconfig.sh must not patch third-party runtime feeds" >&2
	exit 1
fi

echo "test_third_party_runtime_feeds_disabled: ok"
