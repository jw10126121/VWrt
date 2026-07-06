#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CONFIG_DIR=$(cd "$SCRIPT_DIR/../Config/overlays" && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

if [ -e "$CONFIG_DIR/apk.txt" ]; then
	echo "apk overlay should be removed; package manager is now controlled by WRT_PACKAGE_MANAGER + diy_config.sh" >&2
	exit 1
fi

if [ -e "$CONFIG_DIR/ipk.txt" ]; then
	echo "ipk overlay should be removed; package manager is now controlled by WRT_PACKAGE_MANAGER + diy_config.sh" >&2
	exit 1
fi

if sed -n '1,220p' "$EXPORT_SCRIPT" | grep -Eq -- '--overlay[^[:cntrl:]]*(apk|ipk)|frps,apk'; then
	echo "export_config help should not advertise apk/ipk overlays anymore" >&2
	exit 1
fi

echo "test_package_manager_overlays: ok"
