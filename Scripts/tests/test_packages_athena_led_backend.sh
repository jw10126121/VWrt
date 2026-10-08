#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
target_script="$repo_root/Scripts/Packages.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

extract_function() {
    awk -v name="$1" '
        $0 ~ "^" name "\\(\\) \\{" { printing=1 }
        printing { print }
        printing && /^}/ { exit }
    ' "$target_script"
}

for name in find_package_dirs normalize_repo_url DELETE_PACKAGE MOVE_PACKAGE_FROM_LIST update_package_list; do
    extract_function "$name" >> "$test_dir/functions.sh"
done
. "$test_dir/functions.sh"

# 上游 LuCI2-JS 同时提供前端、Rust 后端。只替换网络下载，执行真实复制逻辑。
mkdir -p "$test_dir/upstream/luci-app-athena-led" "$test_dir/upstream/athena-led/src"
printf '%s\n' 'LUCI_DEPENDS:=+luci-base +athena-led +zoneinfo-core +zoneinfo-asia' > "$test_dir/upstream/luci-app-athena-led/Makefile"
printf '%s\n' 'PKG_NAME:=athena-led' 'PKG_BUILD_DEPENDS:=rust/host' > "$test_dir/upstream/athena-led/Makefile"
printf '%s\n' '[package]' 'name = "athena-led"' > "$test_dir/upstream/athena-led/Cargo.toml"
printf '%s\n' '# lockfile fixture' > "$test_dir/upstream/athena-led/Cargo.lock"
printf '%s\n' 'fn main() {}' > "$test_dir/upstream/athena-led/src/main.rs"
clone_repo_shallow() {
    cp -R "$test_dir/upstream" "$3"
}

mkdir -p "$test_dir/openwrt/package/emortal/luci-app-athena-led" "$test_dir/openwrt/package/athena-led" "$test_dir/openwrt/feeds/luci" "$test_dir/openwrt/feeds/packages"
printf old > "$test_dir/openwrt/package/emortal/luci-app-athena-led/old"
printf old > "$test_dir/openwrt/package/athena-led/old"
cd "$test_dir/openwrt/package"
athena_call="$(extract_function apply_common_package_overrides | sed -n '/^[[:space:]]*update_package_list .*"Sh1rokoDev\/luci-app-athena-led"/p')"
test -n "$athena_call"
eval "$athena_call"

if [ ! -f athena-led/Makefile ]; then
    echo 'ASSERT FAILED: LED frontend requires the athena-led backend package from the same repository' >&2
    exit 1
fi
grep -Fq '+athena-led' luci-app-athena-led/Makefile
grep -Fxq 'PKG_NAME:=athena-led' athena-led/Makefile
test -f athena-led/Cargo.toml
test -f athena-led/Cargo.lock
test -f athena-led/src/main.rs
test ! -f athena-led/old
test ! -d emortal/luci-app-athena-led
test ! -d pkglist_Sh1rokoDev_luci-app-athena-led
echo 'test_packages_athena_led_backend: ok'
