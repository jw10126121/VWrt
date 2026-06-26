#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CONFIG_DIR=$(cd "$SCRIPT_DIR/../Config/overlays" && pwd)

grep -q '^CONFIG_PKG_FORMAT=apk$' "$CONFIG_DIR/apk.txt"
grep -q '^CONFIG_USE_APK=y$' "$CONFIG_DIR/apk.txt"

grep -q '^CONFIG_PKG_FORMAT=ipk$' "$CONFIG_DIR/ipk.txt"
grep -q '^CONFIG_USE_APK=n$' "$CONFIG_DIR/ipk.txt"

echo "test_package_manager_overlays: ok"
