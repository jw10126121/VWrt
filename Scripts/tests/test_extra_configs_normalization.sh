#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXTRA_CONFIG_LIB="$SCRIPT_DIR/lib/extra_configs.sh"

. "$EXTRA_CONFIG_LIB"

test "$(normalize_extra_config_entry 'luci-app-mmw')" = 'CONFIG_PACKAGE_luci-app-mmw=y'
test "$(normalize_extra_config_entry 'luci-app-mmw=y')" = 'CONFIG_PACKAGE_luci-app-mmw=y'
test "$(normalize_extra_config_entry 'CONFIG_PACKAGE_luci-app-mmw=m')" = 'CONFIG_PACKAGE_luci-app-mmw=m'

NORMALIZED=$(
	printf 'luci-app-mmw\nluci-app-store=m,CONFIG_PACKAGE_dnsmasq_full_tftp=n\n' | normalize_extra_config_stream
)

printf '%s\n' "$NORMALIZED" | grep -qx 'CONFIG_PACKAGE_luci-app-mmw=y'
printf '%s\n' "$NORMALIZED" | grep -qx 'CONFIG_PACKAGE_luci-app-store=m'
printf '%s\n' "$NORMALIZED" | grep -qx 'CONFIG_PACKAGE_dnsmasq_full_tftp=n'

MIXED_DELIMITERS=$(
	printf 'luci-app-mmw luci-app-store=m，CONFIG_PACKAGE_dnsmasq_full_tftp=n\tluci-app-argon-config\n' | normalize_extra_config_stream
)

printf '%s\n' "$MIXED_DELIMITERS" | grep -qx 'CONFIG_PACKAGE_luci-app-mmw=y'
printf '%s\n' "$MIXED_DELIMITERS" | grep -qx 'CONFIG_PACKAGE_luci-app-store=m'
printf '%s\n' "$MIXED_DELIMITERS" | grep -qx 'CONFIG_PACKAGE_dnsmasq_full_tftp=n'
printf '%s\n' "$MIXED_DELIMITERS" | grep -qx 'CONFIG_PACKAGE_luci-app-argon-config=y'

if normalize_extra_config_entry 'luci-app-mmw=yes' >/dev/null 2>&1; then
	echo "invalid extra config state should fail" >&2
	exit 1
fi

echo "test_extra_configs_normalization: ok"
