#!/bin/bash

# 说明：Packages Artifact 必须上传目录，让 GitHub 的 ZIP 成为唯一压缩层。

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/CORE-ALL.yml"

grep -Fq 'name: ${{ env.OUTPUT_NAME_PREFIX }}-packages' "$WORKFLOW_FILE"
grep -Fq 'path: ${{ env.OPENWRT_PATH }}/upload/${{ env.OUTPUT_NAME_PREFIX }}_Packages' "$WORKFLOW_FILE"
grep -Fq '!${{ env.OPENWRT_PATH }}/upload/*_Packages.zip' "$WORKFLOW_FILE"
grep -Fq '!${{ env.OPENWRT_PATH }}/upload/*_Packages/**' "$WORKFLOW_FILE"
if grep -Fq 'path: ${{ env.OPENWRT_PATH }}/upload/*_Packages.tar.gz' "$WORKFLOW_FILE"; then
	echo "Packages Artifact must not upload a nested tarball" >&2
	exit 1
fi

echo "test_core_all_packages_artifact: ok"
