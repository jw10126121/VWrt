#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")/.." && pwd)
resolver="$script_dir/resolve_source_package_manager.sh"
source_root=$(mktemp -d)
trap 'rm -rf "$source_root"' EXIT
mkdir -p "$source_root/config"
kconfig="$source_root/config/Config-build.in"

assert_manager() {
    local expected=$1 actual
    shift
    printf '%s\n' "$@" > "$kconfig"
    actual=$(bash "$resolver" "$source_root")
    test "$actual" = "$expected"
}

assert_manager apk 'config USE_APK' '  imply PACKAGE_apk-openssl' '  bool "Use APK"' '' '  default y # upstream default'
assert_manager ipk 'config USE_APK' '  bool "Use APK"' '  default n' '  default y'
assert_manager apk 'menuconfig USE_APK' '  def_bool y'
assert_manager ipk 'config USE_APK' '  bool "Use APK"' '' 'config TESTING_KERNEL' '  default y'
assert_manager ipk 'config USE_APK_EXPERIMENTAL' '  def_bool y'

printf '%s\n' 'config USE_APK' '  default y if TARGET_qualcommax' > "$kconfig"
if bash "$resolver" "$source_root" > /dev/null 2> "$source_root/error"; then
    exit 1
fi
grep -Fq '请显式指定 apk 或 ipk' "$source_root/error"

echo 'test_resolve_source_package_manager: ok'
