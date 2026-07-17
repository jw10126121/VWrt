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

grep -q '^ensure_luci_app_ddns_acl() {' "$TARGET_SCRIPT"

POST_FIX_BODY=$(awk '
	/^apply_post_update_fixes\(\) \{/ { printing=1; next }
	printing && /^}/ { exit }
	printing { print }
' "$TARGET_SCRIPT")

printf '%s\n' "$POST_FIX_BODY" | grep -q '^    ensure_luci_app_ddns_acl$'

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

FUNCTIONS_FILE="$TMPDIR/functions.sh"
extract_function "ensure_luci_app_ddns_acl" > "$FUNCTIONS_FILE"

TEST_REPO="$TMPDIR/package"
ACL_FILE="$TEST_REPO/luci-app-ddns/root/usr/share/rpcd/acl.d/luci-app-ddns.json"
mkdir -p "$(dirname "$ACL_FILE")"

cat > "$ACL_FILE" <<'EOF'
{
	"luci-app-ddns": {
		"read": {
			"file": {
				"/usr/bin/ddns": [ "exec" ]
			}
		}
	}
}
EOF

(
	cd "$TEST_REPO"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	ensure_luci_app_ddns_acl
)

grep -Fq '"/etc/init.d/ddns": [ "exec" ]' "$ACL_FILE"
cp "$ACL_FILE" "$TMPDIR/luci-app-ddns.json.once"

(
	cd "$TEST_REPO"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	ensure_luci_app_ddns_acl
)

cmp -s "$ACL_FILE" "$TMPDIR/luci-app-ddns.json.once"

MISSING_REPO="$TMPDIR/missing-package"
mkdir -p "$MISSING_REPO"
(
	cd "$MISSING_REPO"
	# shellcheck disable=SC1090
	. "$FUNCTIONS_FILE"
	ensure_luci_app_ddns_acl
)

echo "test_luci_app_ddns_acl: ok"
