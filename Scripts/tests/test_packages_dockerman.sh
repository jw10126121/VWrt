#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
target_script="$repo_root/Scripts/Packages.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

for name in find_package_dirs normalize_repo_url DELETE_PACKAGE MOVE_PACKAGE_FROM_LIST update_package_list update_dockerman_packages; do
    awk -v name="$name" '
        $0 ~ "^" name "\\(\\) \\{" { printing=1 }
        printing { print }
        printing && /^}/ { exit }
    ' "$target_script" >> "$test_dir/functions.sh"
done
. "$test_dir/functions.sh"

if ! declare -F update_dockerman_packages >/dev/null; then
    update_dockerman_packages() {
        update_package_list 'runc luci-lib-docker luci-app-dockerman dockerd docker docker-compose containerd' "$@"
    }
fi

backend_packages='docker dockerd containerd runc docker-compose'
fixture="$test_dir/fixtures/flat"
mkdir -p "$fixture/luci-lib-docker" "$fixture/luci-app-dockerman"
printf 'new-luci\n' > "$fixture/luci-lib-docker/Makefile"
printf 'new-luci\n' > "$fixture/luci-app-dockerman/Makefile"
for package_name in $backend_packages; do
    mkdir -p "$fixture/$package_name"
    printf 'PKG_VERSION:=29.9.3\n' > "$fixture/$package_name/Makefile"
done
cat >> "$fixture/runc/Makefile" <<'EOF'
include ../../lang/golang/golang-package.mk
.PHONY: check
check:
	@test "$(GO_LAYOUT_OK)" = yes
EOF
cat >> "$fixture/dockerd/Makefile" <<'EOF'
include ../tini/Makefile
.PHONY: check
check:
	@test "$(TINI_LAYOUT_OK)" = yes
	@test -f ../docker/Makefile -a -f ../containerd/Makefile -a -f ../runc/Makefile
	@./git-short-commit.sh
EOF
printf '#!/bin/sh\nexit 0\n' > "$fixture/dockerd/git-short-commit.sh"
chmod -x "$fixture/dockerd/git-short-commit.sh"

clone_repo_shallow() {
    test "$1" = https://github.com/XiaoHaiSly/openwrt-packages.git
    test "$2" = main
    cp -R "$fixture/." "$3/"
}

setup_tree() {
    local case_name=$1
    local package_name
    mkdir -p "$test_dir/$case_name/package/feeds/packages" "$test_dir/$case_name/feeds/luci" \
        "$test_dir/$case_name/feeds/packages/utils/tini" "$test_dir/$case_name/feeds/packages/lang/golang"
    cd "$test_dir/$case_name/package"
    printf 'GO_LAYOUT_OK:=yes\n' > ../feeds/packages/lang/golang/golang-package.mk
    printf 'PKG_VERSION:=0.19.0\nTINI_LAYOUT_OK:=yes\n' > ../feeds/packages/utils/tini/Makefile
    for package_name in $backend_packages; do
        mkdir -p "../feeds/packages/utils/$package_name" "$package_name"
        printf 'old-feed\n' > "../feeds/packages/utils/$package_name/Makefile"
        printf 'old-flat\n' > "$package_name/Makefile"
        ln -s "../../../feeds/packages/utils/$package_name" "feeds/packages/$package_name"
    done
}

check_layout() {
    local package_name
    for package_name in $backend_packages; do
        if ! grep -q '^PKG_VERSION:=29.9.3$' "../feeds/packages/utils/$package_name/Makefile"; then
            echo "ASSERT FAILED: $package_name must replace the package in feeds/packages/utils" >&2
            exit 1
        fi
        test ! -d "$package_name"
        test -f "feeds/packages/$package_name/Makefile"
    done
    test "$(cat luci-app-dockerman/Makefile)" = new-luci
    test "$(cat luci-lib-docker/Makefile)" = new-luci
    grep -q '^PKG_VERSION:=0.19.0$' ../feeds/packages/utils/tini/Makefile
    test -x ../feeds/packages/utils/dockerd/git-short-commit.sh
    test -z "$(find . -maxdepth 1 -type d -name 'pkglist_*' -print)"
    make -s -C ../feeds/packages/utils/runc check
    make -s -C ../feeds/packages/utils/dockerd check
}

setup_tree flat
update_dockerman_packages XiaoHaiSly/openwrt-packages main > "$test_dir/flat.log" 2>&1
check_layout
update_dockerman_packages XiaoHaiSly/openwrt-packages main >> "$test_dir/flat.log" 2>&1
check_layout
echo 'test_packages_dockerman_flat_and_repeat: ok'

mkdir -p "$test_dir/fixtures/nested/luci-app-dockerman"
cp -R "$fixture/." "$test_dir/fixtures/nested/luci-app-dockerman/"
mv "$test_dir/fixtures/nested/luci-app-dockerman/luci-app-dockerman/Makefile" "$test_dir/fixtures/nested/luci-app-dockerman/Makefile"
rmdir "$test_dir/fixtures/nested/luci-app-dockerman/luci-app-dockerman"
fixture="$test_dir/fixtures/nested"
setup_tree nested
update_dockerman_packages XiaoHaiSly/openwrt-packages main > "$test_dir/nested.log" 2>&1
check_layout
test ! -d luci-app-dockerman/docker
test ! -d luci-app-dockerman/luci-lib-docker
echo 'test_packages_dockerman_nested: ok'

fixture="$test_dir/fixtures/partial"
mkdir -p "$fixture/docker" "$fixture/containerd"
printf 'PKG_VERSION:=30.0.0\n' > "$fixture/docker/Makefile"
setup_tree partial
printf 'PKG_VERSION:=29.9.3\n' > ../feeds/packages/utils/dockerd/Makefile
update_dockerman_packages XiaoHaiSly/openwrt-packages main > "$test_dir/partial.log" 2>&1
test "$(cat ../feeds/packages/utils/containerd/Makefile)" = old-feed
test "$(cat ../feeds/packages/utils/runc/Makefile)" = old-feed
test "$(cat ../feeds/packages/utils/dockerd/Makefile)" = PKG_VERSION:=29.9.3
grep -q 'WARNING:.*30.0.0.*29.9.3' "$test_dir/partial.log"
echo 'test_packages_dockerman_missing_and_versions: ok'

setup_tree clone_failure
clone_repo_shallow() {
    printf partial > "$3/partial"
    return 128
}
if update_dockerman_packages XiaoHaiSly/openwrt-packages main > "$test_dir/failure.log" 2>&1; then
    echo 'ASSERT FAILED: clone failure must return an error' >&2
    exit 1
else
    test "$?" -eq 128
fi
test "$(cat ../feeds/packages/utils/docker/Makefile)" = old-feed
test "$(cat docker/Makefile)" = old-flat
test -z "$(find . -maxdepth 1 -type d -name 'pkglist_*' -print)"
echo 'test_packages_dockerman_clone_failure: ok'

mkdir -p "$test_dir/no_feed/package/docker"
cd "$test_dir/no_feed/package"
printf unchanged > docker/Makefile
update_dockerman_packages XiaoHaiSly/openwrt-packages main > "$test_dir/no_feed.log" 2>&1
test "$(cat docker/Makefile)" = unchanged
echo 'test_packages_dockerman_no_feed: ok'

awk '/^apply_iwrt_package_overrides\(\) \{/,/^}/' "$target_script" | \
    grep -q 'update_dockerman_packages "XiaoHaiSly/openwrt-packages" "main"'
echo 'test_packages_dockerman_iwrt_integration: ok'
