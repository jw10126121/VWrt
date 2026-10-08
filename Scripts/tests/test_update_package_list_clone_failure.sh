#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
target_script="$repo_root/Scripts/Packages.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

for name in find_package_dirs normalize_repo_url DELETE_PACKAGE MOVE_PACKAGE_FROM_LIST update_package_list; do
    awk -v name="$name" '
        $0 ~ "^" name "\\(\\) \\{" { printing=1 }
        printing { print }
        printing && /^}/ { exit }
    ' "$target_script" >> "$test_dir/functions.sh"
done
. "$test_dir/functions.sh"

mkdir -p "$test_dir/openwrt/package/luci-app-adguardhome" "$test_dir/openwrt/feeds/luci" "$test_dir/openwrt/feeds/packages/lang/node"
printf old-adguard > "$test_dir/openwrt/package/luci-app-adguardhome/Makefile"
printf old-node > "$test_dir/openwrt/feeds/packages/lang/node/Makefile"
cd "$test_dir/openwrt/package"

clone_repo_shallow() {
    mkdir -p "$3"
    printf partial > "$3/partial"
    return 128
}
if update_package_list 'luci-app-substore node luci-app-adguardhome' 'XiaoHaiSly/OpenWRT-packages' main > "$test_dir/output.log" 2>&1; then
    echo 'ASSERT FAILED: package list clone failure must not report success' >&2
    exit 1
fi
test "$(cat luci-app-adguardhome/Makefile)" = old-adguard
test "$(cat ../feeds/packages/lang/node/Makefile)" = old-node
test ! -d pkglist_XiaoHaiSly_OpenWRT-packages
if grep -q '成功clone插件包库' "$test_dir/output.log"; then
    echo 'ASSERT FAILED: failed clone must not print a success message' >&2
    exit 1
fi
echo 'test_update_package_list_clone_failure: ok'

# 仓库可下载但某个目标包不存在时，只替换找到的包，保留未找到的旧包。
clone_repo_shallow() {
    mkdir -p "$3/luci-app-adguardhome"
    printf new-adguard > "$3/luci-app-adguardhome/Makefile"
}
update_package_list 'node luci-app-adguardhome' 'example/packages' main
test "$(cat luci-app-adguardhome/Makefile)" = new-adguard
test "$(cat ../feeds/packages/lang/node/Makefile)" = old-node
test ! -d pkglist_example_packages
echo 'test_update_package_list_missing_package: ok'
