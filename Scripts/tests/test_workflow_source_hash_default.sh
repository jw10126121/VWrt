#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
hash_input="$(sed -n '/^      WRT_SOURCE_HASH_INFO:/,/^#CI权限/p' "$repo_root/.github/workflows/CUSTOM-iwrt-all.yml")"
if ! printf '%s\n' "$hash_input" | grep -Eq "^[[:space:]]+default: ''[[:space:]]*(#.*)?$"; then
    echo 'ASSERT FAILED: source HASH must default to empty to follow the selected branch' >&2
    exit 1
fi
grep -Fq 'git fetch --depth=1 origin "${WRT_SOURCE_HASH_INFO}"' "$repo_root/.github/workflows/CORE-ALL.yml"
grep -Fq 'git checkout "${WRT_SOURCE_HASH_INFO}"' "$repo_root/.github/workflows/CORE-ALL.yml"
echo 'test_workflow_source_hash_default: ok'
