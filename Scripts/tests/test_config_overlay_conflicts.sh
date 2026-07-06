#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/overlays"

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_COMMON=y
EOF

cat > "$TMPDIR/DEVICE-A.txt" <<'EOF'
CONFIG_DEVICE=device-a
EOF

cat > "$TMPDIR/overlays/frps.txt" <<'EOF'
# OVERLAY_GROUP=frp
CONFIG_FRP_ROLE=server
EOF

cat > "$TMPDIR/overlays/frpc.txt" <<'EOF'
# OVERLAY_GROUP=frp
CONFIG_FRP_ROLE=client
EOF

cat > "$TMPDIR/overlays/usb.txt" <<'EOF'
# OVERLAY_GROUP=usb
CONFIG_USB_PROFILE=full
EOF

cat > "$TMPDIR/overlays/nousb.txt" <<'EOF'
# OVERLAY_GROUP=usb
CONFIG_USB_PROFILE=none
EOF

OUT="$TMPDIR/merged.txt"
SECOND_OUT="$TMPDIR/merged-second.txt"

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw3" \
	--overlay "frps,usb,frpc,nousb" \
	--output "$OUT"

grep -q '^CONFIG_COMMON=y$' "$OUT"
grep -q '^CONFIG_DEVICE=device-a$' "$OUT"
grep -q '^CONFIG_FRP_ROLE=client$' "$OUT"
grep -q '^CONFIG_USB_PROFILE=none$' "$OUT"
if grep -q '^CONFIG_FRP_ROLE=server$' "$OUT"; then
	echo "earlier frp overlay should be dropped" >&2
	exit 1
fi
if grep -q '^CONFIG_USB_PROFILE=full$' "$OUT"; then
	echo "earlier usb overlay should be dropped" >&2
	exit 1
fi

bash "$EXPORT_SCRIPT" \
	--config-dir "$TMPDIR" \
	--device "DEVICE-A" \
	--fw "fw3" \
	--overlay "nousb,usb,frpc,frps" \
	--output "$SECOND_OUT"

grep -q '^CONFIG_FRP_ROLE=server$' "$SECOND_OUT"
grep -q '^CONFIG_USB_PROFILE=full$' "$SECOND_OUT"

echo "test_config_overlay_conflicts: ok"
