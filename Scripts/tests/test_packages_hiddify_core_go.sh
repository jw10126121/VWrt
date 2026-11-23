#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

eval "$(awk '/^fix_hiddify_core_go_toolchain\(\) \{/ { printing=1 } printing { print } printing && /^}/ { exit }' "$script_dir/Packages.sh")"

mkdir -p "$test_dir/package/hiddify-core" "$test_dir/package/other-go-package"
cd "$test_dir/package"

makefile='hiddify-core/Makefile'
default_dependency='PKG_BUILD_DEPENDS:=golang/host'
printf '%s\n' "$default_dependency" > "$makefile"
printf '%s\n' "$default_dependency" > other-go-package/Makefile

fix_hiddify_core_go_toolchain
grep -Fxq "$default_dependency" "$makefile"

mkdir -p ../feeds/packages/lang/golang/golang1.27
touch ../feeds/packages/lang/golang/golang1.27/Makefile
fix_hiddify_core_go_toolchain
fix_hiddify_core_go_toolchain
grep -Fxq 'PKG_BUILD_DEPENDS:=golang1.27/host' "$makefile"
grep -Fxq "$default_dependency" other-go-package/Makefile

printf '%s\n' 'PKG_BUILD_DEPENDS:=golang1.28/host' > "$makefile"
fix_hiddify_core_go_toolchain
grep -Fxq 'PKG_BUILD_DEPENDS:=golang1.28/host' "$makefile"

echo 'test_packages_hiddify_core_go: ok'
