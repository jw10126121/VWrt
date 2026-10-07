#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

# 兼容本地 macOS 的 BSD sed，Actions 上直接使用 GNU sed。
if [ "$(uname -s)" = Darwin ]; then
    mkdir -p "$test_dir/bin"
    cat > "$test_dir/bin/sed" <<'EOF'
#!/bin/sh
if [ "$1" = -i ]; then
    shift
    exec /usr/bin/sed -i '' "$@"
fi
exec /usr/bin/sed "$@"
EOF
    chmod +x "$test_dir/bin/sed"
    export PATH="$test_dir/bin:$PATH"
fi

mkdir -p "$test_dir/fresh" "$test_dir/inherited"
printf '%s\n' 'src-git packages https://example.com/packages.git' > "$test_dir/fresh/feeds.conf.default"
cp "$test_dir/fresh/feeds.conf.default" "$test_dir/inherited/feeds.conf.default"
cat >> "$test_dir/inherited/feeds.conf.default" <<'EOF'
src-git miaomiaowu https://github.com/xiaohai77/OpenWrt-MMW.git
  src-git-full miaomiaowu https://example.com/old.git;main
#src-git miaomiaowu https://example.com/commented.git
src-git miaomiaowu-extra https://example.com/unrelated.git
EOF

for case_name in fresh inherited; do
    (
        cd "$test_dir/$case_name"
        WRT_LUCI_BRANCH='' bash "$repo_root/Scripts/diy_feeds.sh"
        if grep -Eq '^[[:space:]]*src-[^[:space:]]+[[:space:]]+miaomiaowu([[:space:]]|$)' feeds.conf.default; then
            echo "ASSERT FAILED: unavailable miaomiaowu feed must not remain active ($case_name)" >&2
            exit 1
        fi
        grep -Fxq 'src-git packages https://example.com/packages.git' feeds.conf.default
        grep -Fq 'src-git istore https://github.com/linkease/istore;main' feeds.conf.default
        cp feeds.conf.default first-run.conf
        WRT_LUCI_BRANCH='' bash "$repo_root/Scripts/diy_feeds.sh"
        cmp first-run.conf feeds.conf.default
    )
done
grep -Fxq 'src-git miaomiaowu-extra https://example.com/unrelated.git' "$test_dir/inherited/feeds.conf.default"
grep -Fxq '#src-git miaomiaowu https://example.com/commented.git' "$test_dir/inherited/feeds.conf.default"
echo 'test_diy_feeds_unavailable_feed: ok'
