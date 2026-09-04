#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/Packages.sh"
TMPDIR=$(mktemp -d)

cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

extract_function() {
    awk '
        /^clone_repo_shallow\(\) \{/ { printing=1 }
        printing { print }
        printing && /^}/ { exit }
    ' "$TARGET_SCRIPT"
}

extract_function > "$TMPDIR/functions.sh"

mkdir -p "$TMPDIR/bin"
cat > "$TMPDIR/bin/git" <<'EOF'
#!/bin/bash
if [ "$1" = "ls-remote" ]; then
    printf '%s\n' "$*" >> "$GIT_ARGS_FILE"
    exit "${GIT_LS_REMOTE_STATUS:-2}"
fi

printf '%s\n' "$*" >> "$GIT_ARGS_FILE"
EOF
chmod +x "$TMPDIR/bin/git"

# shellcheck disable=SC1090
. "$TMPDIR/functions.sh"

PATH="$TMPDIR/bin:$PATH" \
GIT_ARGS_FILE="$TMPDIR/branch.args" \
clone_repo_shallow "https://example.com/repo.git" "main" "repo"
grep -Fxq 'clone --depth=1 --single-branch --branch main https://example.com/repo.git repo' "$TMPDIR/branch.args"

commit_hash='0123456789abcdef0123456789abcdef01234567'
PATH="$TMPDIR/bin:$PATH" \
GIT_ARGS_FILE="$TMPDIR/hash.args" \
clone_repo_shallow "https://example.com/repo.git" "$commit_hash" "repo"
grep -Fxq "ls-remote --exit-code --heads --tags https://example.com/repo.git $commit_hash" "$TMPDIR/hash.args"
grep -Fxq 'init -q repo' "$TMPDIR/hash.args"
grep -Fxq -- '-C repo remote add origin https://example.com/repo.git' "$TMPDIR/hash.args"
grep -Fxq -- "-C repo fetch --depth=1 origin $commit_hash" "$TMPDIR/hash.args"
grep -Fxq -- '-C repo checkout --detach FETCH_HEAD' "$TMPDIR/hash.args"

hex_branch='abcdefabcdefabcdefabcdefabcdefabcdefabcd'
PATH="$TMPDIR/bin:$PATH" \
GIT_ARGS_FILE="$TMPDIR/hex-branch.args" \
GIT_LS_REMOTE_STATUS=0 \
clone_repo_shallow "https://example.com/repo.git" "$hex_branch" "repo"
grep -Fxq "ls-remote --exit-code --heads --tags https://example.com/repo.git $hex_branch" "$TMPDIR/hex-branch.args"
grep -Fxq "clone --depth=1 --single-branch --branch $hex_branch https://example.com/repo.git repo" "$TMPDIR/hex-branch.args"

echo "test_packages_git_ref_checkout: ok"
