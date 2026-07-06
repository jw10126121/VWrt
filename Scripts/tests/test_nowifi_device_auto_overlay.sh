#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

cat > "$TMPDIR/general.txt" <<'EOF'
CONFIG_COMMON=y
EOF

mkdir -p "$TMPDIR/overlays"

cat > "$TMPDIR/cmiot-ax18-wifi-fw3.txt" <<'EOF'
CONFIG_PACKAGE_kmod-ath11k=y
CONFIG_PACKAGE_kmod-ath11k-ahb=y
CONFIG_PACKAGE_wpad-openssl=y
EOF

cat > "$TMPDIR/overlays/nowifi-ipq60xx.txt" <<'EOF'
# OVERLAY_GROUP=nowifi
CONFIG_PACKAGE_kmod-ath11k=n
CONFIG_PACKAGE_kmod-ath11k-ahb=n
CONFIG_PACKAGE_wpad-openssl=n
EOF

WIFI_OUT="$TMPDIR/wifi.txt"
NOWIFI_OUT="$TMPDIR/nowifi.txt"

bash "$EXPORT_SCRIPT" --config-dir "$TMPDIR" --device "cmiot-ax18-wifi" --fw "fw3" --output "$WIFI_OUT" >/dev/null
bash "$EXPORT_SCRIPT" --config-dir "$TMPDIR" --device "cmiot-ax18-nowifi" --fw "fw3" --output "$NOWIFI_OUT" >/dev/null

grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$WIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=y'
grep -n '^CONFIG_PACKAGE_kmod-ath11k=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_kmod-ath11k=n'
grep -n '^CONFIG_PACKAGE_wpad-openssl=' "$NOWIFI_OUT" | tail -n 1 | grep -q 'CONFIG_PACKAGE_wpad-openssl=n'

echo "test_nowifi_device_auto_overlay: ok"
