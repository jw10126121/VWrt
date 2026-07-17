#!/bin/bash

# 说明：验证 diy_after_defconfig 里的 HomeProxy 资源预置只在启用时执行，
# 且下载或转换失败时不会用空数据覆盖已有资源。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/diy_after_defconfig.sh"

TMPDIR=$(mktemp -d)
TEST_BIN="$TMPDIR/test-bin"
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TEST_BIN"
SYSTEM_AWK=$(command -v awk)

cat > "$TEST_BIN/git" <<'EOF'
#!/bin/sh
case "$1" in
clone)
	target_dir=""
	for argument in "$@"; do
		target_dir="$argument"
	done
	case "${HOME_PROXY_GIT_MODE:-success}" in
		clone-fail)
			exit 1
			;;
		missing-input)
			mkdir -p "$target_dir"
			printf '.example.cn\n' > "$target_dir/direct.txt"
			printf '.example.com\n' > "$target_dir/gfw.txt"
			echo "git-clone-called" >> "$HOME_PROXY_GIT_MARKER"
			exit 0
			;;
	esac
	mkdir -p "$target_dir"
	printf 'IP-CIDR,1.1.1.0/24\n' > "$target_dir/cncidr.txt"
	printf 'IP-CIDR6,2001:db8::/32\n' >> "$target_dir/cncidr.txt"
	printf '.example.cn\n' > "$target_dir/direct.txt"
	printf '.example.com\n' > "$target_dir/gfw.txt"
	echo "git-clone-called" >> "$HOME_PROXY_GIT_MARKER"
	exit 0
	;;
log)
	echo "20260420"
	exit 0
	;;
*)
	echo "git-other-called" >> "$HOME_PROXY_GIT_MARKER"
	exit 0
	;;
esac
EOF
chmod +x "$TEST_BIN/git"

cat > "$TEST_BIN/awk" <<'EOF'
#!/bin/sh
for argument in "$@"; do
	if [ "${HOME_PROXY_GIT_MODE:-success}" = "conversion-fail" ] && [ "${argument##*/}" = "cncidr.txt" ]; then
		exit 1
	fi
done
exec "$HOME_PROXY_SYSTEM_AWK" "$@"
EOF
chmod +x "$TEST_BIN/awk"

extract_function() {
	local function_name=$1
	awk -v name="$function_name" '
		$0 ~ "^" name "\\(\\) *\\{" { printing=1 }
		printing { print }
		printing && $0 == "}" { exit }
	' "$TARGET_SCRIPT"
}

BLOCK_FILE="$TMPDIR/homeproxy_block.sh"
{
	extract_function "get_config_value"
	extract_function "preload_homeproxy_resources"
} > "$BLOCK_FILE"

run_case() {
	local mode=$1
	local git_mode=$2
	local case_dir="$TMPDIR/$mode"
	local homeproxy_dir="$case_dir/package/feeds/luci/luci-app-homeproxy"
	local marker="$case_dir/git.marker"

	mkdir -p "$homeproxy_dir/root/etc/homeproxy/scripts" "$homeproxy_dir/root/etc/homeproxy/resources"
	printf '#!/bin/sh\nexit 0\n' > "$homeproxy_dir/root/etc/homeproxy/scripts/test.sh"
	chmod +x "$homeproxy_dir/root/etc/homeproxy/scripts/test.sh"

	cat > "$case_dir/.config" <<EOF
CONFIG_PACKAGE_luci-app-homeproxy=$([ "$mode" = disabled ] && echo n || echo y)
EOF

	(
		cd "$case_dir"
		openwrt_workdir="$case_dir"
		export HOME_PROXY_GIT_MARKER="$marker"
		export HOME_PROXY_GIT_MODE="$git_mode"
		export HOME_PROXY_SYSTEM_AWK="$SYSTEM_AWK"
		PATH="$TEST_BIN:$PATH"
		if [ "$mode" = disabled ]; then
			PRELOAD_HOMEPROXY_RESOURCES=false
		else
			PRELOAD_HOMEPROXY_RESOURCES=true
		fi
		export PRELOAD_HOMEPROXY_RESOURCES
		# shellcheck disable=SC1090
		. "$BLOCK_FILE"
		preload_homeproxy_resources
	)
}

run_case disabled success

if [ -f "$TMPDIR/disabled/git.marker" ]; then
	echo "HomeProxy preload should not run when luci-app-homeproxy is disabled" >&2
	exit 1
fi

run_case enabled success

grep -Fq 'git-clone-called' "$TMPDIR/enabled/git.marker"

for resource in china_ip4 china_ip6 china_list gfw_list; do
	test -s "$TMPDIR/enabled/package/feeds/luci/luci-app-homeproxy/root/etc/homeproxy/resources/${resource}.ver"
	test -s "$TMPDIR/enabled/package/feeds/luci/luci-app-homeproxy/root/etc/homeproxy/resources/${resource}.txt"
done

grep -Fxq '1.1.1.0/24' "$TMPDIR/enabled/package/feeds/luci/luci-app-homeproxy/root/etc/homeproxy/resources/china_ip4.txt"
grep -Fxq '2001:db8::/32' "$TMPDIR/enabled/package/feeds/luci/luci-app-homeproxy/root/etc/homeproxy/resources/china_ip6.txt"
grep -Fxq 'example.cn' "$TMPDIR/enabled/package/feeds/luci/luci-app-homeproxy/root/etc/homeproxy/resources/china_list.txt"
grep -Fxq 'example.com' "$TMPDIR/enabled/package/feeds/luci/luci-app-homeproxy/root/etc/homeproxy/resources/gfw_list.txt"

for failure_mode in clone-fail missing-input conversion-fail; do
	failure_resource_dir="$TMPDIR/$failure_mode/package/feeds/luci/luci-app-homeproxy/root/etc/homeproxy/resources"
	expected_resource_dir="$TMPDIR/$failure_mode/expected-resources"
	mkdir -p "$failure_resource_dir"
	mkdir -p "$expected_resource_dir"
	printf 'keep\n' > "$failure_resource_dir/keep.txt"
	cp "$failure_resource_dir/keep.txt" "$expected_resource_dir/keep.txt"
	for resource in china_ip4 china_ip6 china_list gfw_list; do
		printf 'old-%s\n' "$resource" > "$failure_resource_dir/${resource}.txt"
		printf 'old-version\n' > "$failure_resource_dir/${resource}.ver"
		cp "$failure_resource_dir/${resource}.txt" "$expected_resource_dir/${resource}.txt"
		cp "$failure_resource_dir/${resource}.ver" "$expected_resource_dir/${resource}.ver"
	done

	if run_case "$failure_mode" "$failure_mode"; then
		echo "HomeProxy preload should fail when ${failure_mode}" >&2
		exit 1
	fi

	cmp -s "$expected_resource_dir/keep.txt" "$failure_resource_dir/keep.txt"
	for resource in china_ip4 china_ip6 china_list gfw_list; do
		cmp -s "$expected_resource_dir/${resource}.txt" "$failure_resource_dir/${resource}.txt"
		cmp -s "$expected_resource_dir/${resource}.ver" "$failure_resource_dir/${resource}.ver"
	done
done

echo "test_diy_after_defconfig_homeproxy_scope: ok"
