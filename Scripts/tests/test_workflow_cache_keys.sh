#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow_file="${repo_root}/.github/workflows/CORE-ALL.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq -- "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq -- "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_toolchain_uses_scoped_restore_key() {
	local restore_block
	restore_block="$(awk '/Restore Toolchain Cache/,/Restore ccache Cache/' "$workflow_file")"

	if ! printf '%s\n' "$restore_block" | grep -Fq -- 'key: ${{ env.TOOLCHAIN_CACHE_KEY }}'; then
		echo "ASSERT FAILED: toolchain restore must use the computed compatibility key" >&2
		exit 1
	fi

	if ! printf '%s\n' "$restore_block" | grep -Fq -- 'restore-keys:'; then
		echo "ASSERT FAILED: toolchain should fall back within the same compatibility scope" >&2
		exit 1
	fi

	if ! printf '%s\n' "$restore_block" | grep -Fq -- '          ${{ env.TOOLCHAIN_CACHE_RESTORE_KEY }}'; then
		echo "ASSERT FAILED: toolchain fallback must use the computed scoped restore key" >&2
		exit 1
	fi
}

assert_restore_ccache_uses_stable_key() {
	local restore_block
	restore_block="$(awk '/Restore ccache Cache/,/Print Build Summary/' "$workflow_file")"

	if ! printf '%s\n' "$restore_block" | grep -Fq -- 'key: ${{ env.CCACHE_CACHE_KEY }}'; then
		echo "ASSERT FAILED: ccache should use its computed configuration key" >&2
		exit 1
	fi

	if ! printf '%s\n' "$restore_block" | grep -Fq -- '${{ env.CCACHE_CACHE_PREFIX }}-'; then
		echo "ASSERT FAILED: ccache should retain a compatible reuse prefix" >&2
		exit 1
	fi
}

assert_contains '- name: Restore Toolchain Cache' "workflow should restore toolchain cache explicitly"
assert_contains 'uses: actions/cache/restore@v5' "workflow should use cache restore actions"
assert_contains '- name: Save Toolchain Cache' "workflow should save toolchain cache explicitly"
assert_contains 'uses: actions/cache/save@v5' "workflow should use cache save actions"
assert_not_contains 'WRT_OVERLAYS_HASH' "workflow should not keep an unused overlays hash variable"
assert_not_contains 'CACHE_SCRIPTS_HASH' "workflow should not include the build scripts hash in cache keys"
assert_contains 'key: ${{ env.TOOLCHAIN_CACHE_KEY }}' "toolchain restore and save should use the computed compatibility key"
assert_contains '          ${{ env.TOOLCHAIN_CACHE_RESTORE_KEY }}' "toolchain restore should use the computed fallback key"
assert_toolchain_uses_scoped_restore_key

assert_contains '- name: Prepare Restored Build Cache (整理恢复的缓存)' "workflow should prepare restored build caches"
assert_contains 'steps.restore_toolchain_cache.outputs.cache-matched-key !=' "cache preparation should run when a toolchain cache was restored"
assert_contains "-not -path 'staging_dir/target-*/*'" "cache preparation should leave target staging stamps untouched"
assert_contains '-exec touch {} +' "cache preparation should refresh restored stamp files"
assert_contains "echo '1' > tmp/.build" "cache preparation should restore the OpenWrt build marker"
assert_contains '- name: Print Cache Status (打印缓存命中状态)' "workflow should report restored cache status"
assert_contains 'cache-matched-key' "workflow should print the matched cache keys"
assert_contains "steps.finalize_compile.outputs.status == 'success' && env.CACHE_TOOLCHAIN" "toolchain should only be saved after a successful build"

python3 - "$workflow_file" <<'PY'
from pathlib import Path
import sys
workflow = Path(sys.argv[1]).read_text()
assert workflow.index('- name: DIY after defconfig') < workflow.index('- name: Compute Cache Keys') < workflow.index('- name: Restore Toolchain Cache'), 'Restore must follow final configuration and key computation'
assert workflow.index('- name: Restore ccache Cache') < workflow.index('- name: Prepare Restored Build Cache') < workflow.index('- name: Print Cache Status'), 'Restored caches must be prepared and reported before the build summary'
for cache in ('Toolchain', 'ccache'):
    restore = workflow.split(f'- name: Restore {cache} Cache', 1)[1].split('\n    - name:', 1)[0]
    save = workflow.split(f'- name: Save {cache} Cache', 1)[1].split('\n    - name:', 1)[0]
    get_key = lambda block: next(line.strip() for line in block.splitlines() if line.strip().startswith('key:'))
    assert get_key(restore) == get_key(save), f'{cache} restore/save keys must agree'
ccache_restore = workflow.split('- name: Restore ccache Cache', 1)[1].split('\n    - name:', 1)[0]
ccache_save = workflow.split('- name: Save ccache Cache', 1)[1].split('\n    - name:', 1)[0]
assert 'github.run_id' not in ccache_restore and 'github.run_attempt' not in ccache_restore, 'ccache exact key must remain stable across runs'
assert "steps.restore_ccache_cache.outputs.cache-hit != 'true'" in ccache_save, 'ccache should only save when the exact key was not restored'
PY

assert_contains '- name: Restore ccache Cache' "workflow should restore ccache explicitly"
assert_contains '- name: Save ccache Cache' "workflow should save ccache explicitly"
assert_contains 'key: ${{ env.CCACHE_CACHE_KEY }}' "ccache restore and save keys should use the computed stable key"
assert_restore_ccache_uses_stable_key
assert_contains 'restore-keys: |' "ccache restore step should still keep restore-keys"
assert_contains '          ${{ env.CCACHE_CACHE_PREFIX }}-' "ccache should restore only within its computed compatibility scope"
assert_contains "steps.restore_ccache_cache.outputs.cache-hit != 'true'" "ccache save should skip an already restored exact cache"
assert_contains 'continue-on-error: true' "cache save steps should tolerate duplicate parallel cache reservations"

assert_contains '- name: Initialize Build Observability' "workflow should initialize build timing observability"
assert_contains 'echo "PREP_STAGE_START_TS=$(date +%s)" >> "$GITHUB_ENV"' "workflow should record the prep stage start timestamp"
assert_not_contains '- name: Evaluate Cache Restore State' "workflow should no longer classify cache restore state for benchmark reporting"
assert_not_contains '- name: Report ccache Stats Before Build' "workflow should no longer capture ccache stats before compilation"
assert_not_contains '- name: Report ccache Stats After Build' "workflow should no longer capture ccache stats after compilation"
assert_not_contains 'CCACHE_DIR="${{ env.OPENWRT_PATH }}/.ccache" ccache -s > "$RUNNER_TEMP/ccache-before.txt" || true' "workflow should no longer persist pre-build ccache stats"
assert_not_contains 'CCACHE_DIR="${{ env.OPENWRT_PATH }}/.ccache" ccache -s > "$RUNNER_TEMP/ccache-after.txt" || true' "workflow should no longer persist post-build ccache stats"
assert_not_contains '- name: Write Build Metrics' "workflow should no longer write benchmark metrics artifacts"
assert_not_contains '- name: Upload Build Metrics' "workflow should no longer upload benchmark metrics artifacts"
assert_not_contains 'name: bench-metrics-' "workflow should no longer upload benchmark metrics under a dedicated artifact prefix"
assert_not_contains "ccache_restore_state=\${{ steps.evaluate_cache_restore_state.outputs.ccache_restore_state || 'no-cache' }}" "workflow should no longer emit ccache restore state metrics"
assert_not_contains "awk -F '[()%]'" "workflow should no longer parse ccache hit rates for benchmark metrics"
assert_not_contains "awk -F '[:/()]'" "workflow should no longer parse ccache cache sizes for benchmark metrics"
assert_not_contains 'sed -nE "s/${pattern}/\\1/p"' "workflow should not use slash-sensitive sed substitutions for metrics extraction"
assert_not_contains '- name: Restore dl Cache' "workflow should not introduce dl cache in this change"
assert_not_contains '- name: Save dl Cache' "workflow should not introduce dl cache in this change"

echo "test_workflow_cache_keys: ok"
