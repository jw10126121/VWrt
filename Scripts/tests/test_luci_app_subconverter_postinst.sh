#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"

extract_function() {
	local fn="$1"

	awk -v name="$fn" '
		$0 ~ "^" name "\\(\\) \\{" { printing=1 }
		printing { print }
		printing && /^}/ { exit }
	' "$TARGET_SCRIPT"
}

grep -q '^fix_luci_app_subconverter_postinst() {' "$TARGET_SCRIPT"

POST_FIX_BODY=$(awk '
	/^apply_post_update_fixes\(\) \{/ { printing=1; next }
	printing && /^}/ { exit }
	printing { print }
' "$TARGET_SCRIPT")

printf '%s\n' "$POST_FIX_BODY" | grep -q '^    fix_luci_app_subconverter_postinst$'

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "fix_luci_app_subconverter_postinst" > "$FUNCTIONS_FILE"

TEST_REPO="$TMPDIR/package"
mkdir -p "$TEST_REPO/luci-app-subconverter"

cat > "$TEST_REPO/luci-app-subconverter/Makefile" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-subconverter

define Package/$(PKG_NAME)/postinst
    #!/bin/sh
    chmod 755 /etc/subconverter/subconverter
endef
EOF

(
	cd "$TEST_REPO"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	fix_luci_app_subconverter_postinst
)

grep -Fq '[ -f "${IPKG_INSTROOT}/etc/subconverter/subconverter" ] || exit 0' \
	"$TEST_REPO/luci-app-subconverter/Makefile"
grep -Fq 'chmod 755 "${IPKG_INSTROOT}/etc/subconverter/subconverter"' \
	"$TEST_REPO/luci-app-subconverter/Makefile"
if grep -Fq 'chmod 755 /etc/subconverter/subconverter' \
	"$TEST_REPO/luci-app-subconverter/Makefile"; then
	echo "absolute chmod path should be replaced with IPKG_INSTROOT-aware path" >&2
	exit 1
fi

cp "$TEST_REPO/luci-app-subconverter/Makefile" "$TMPDIR/Makefile.once"

(
	cd "$TEST_REPO"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	fix_luci_app_subconverter_postinst
)

cmp -s "$TEST_REPO/luci-app-subconverter/Makefile" "$TMPDIR/Makefile.once"

echo "test_luci_app_subconverter_postinst: ok"
