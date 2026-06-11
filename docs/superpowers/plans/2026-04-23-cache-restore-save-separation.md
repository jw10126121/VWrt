# Cache Restore/Save Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the existing `toolchain` and `ccache` GitHub Actions cache steps into explicit restore/save steps, then evolve `ccache` into a rolling snapshot strategy while adding minimal cache/build observability logs.

**Architecture:** Keep `toolchain` on an exact source-hash key, but use explicit `restore/save` steps for both caches. For `ccache`, move from a frozen stable key to rolling `START_TIME` snapshot keys plus prefix fallback so each run restores the newest prior snapshot and saves a hotter one at the end. Add post-restore diagnostics, pre-save diagnostics, build timers, pre/post-build `ccache -s`, and benchmark metrics artifacts so CI can show both wall-clock savings and ccache heating over repeated runs.

**Tech Stack:** GitHub Actions workflow YAML, Bash-based workflow tests, OpenWrt build pipeline

---

### Task 1: Lock The New Workflow Structure In Tests First

**Files:**
- Modify: `/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/tests/test_workflow_cache_keys.sh`
- Test: `/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/tests/test_workflow_cache_keys.sh`

- [ ] **Step 1: Rewrite the workflow cache test to expect restore/save separation**

Replace the current assertions in `/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/tests/test_workflow_cache_keys.sh` with this structure:

```bash
#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow_file="${repo_root}/.github/workflows/CORE-ALL.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_toolchain_has_no_restore_keys() {
	if awk '/Restore Toolchain Cache/,/Restore ccache Cache/' "$workflow_file" | grep -Fq 'restore-keys:'; then
		echo "ASSERT FAILED: toolchain cache should not restore older prefixes" >&2
		exit 1
	fi
}

assert_contains '- name: Restore Toolchain Cache' "workflow should restore toolchain cache explicitly"
assert_contains 'uses: actions/cache/restore@v5' "workflow should use cache restore actions"
assert_contains '- name: Save Toolchain Cache' "workflow should save toolchain cache explicitly"
assert_contains 'uses: actions/cache/save@v5' "workflow should use cache save actions"
assert_contains 'key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}' "toolchain cache key should still include the source commit hash"
assert_toolchain_has_no_restore_keys

assert_contains '- name: Restore ccache Cache' "workflow should restore ccache explicitly"
assert_contains '- name: Save ccache Cache' "workflow should save ccache explicitly"
assert_contains 'key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}' "ccache key should remain unchanged"
assert_contains 'restore-keys: |' "ccache restore step should still keep restore-keys"
assert_contains 'ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-' "ccache restore prefix should remain unchanged"

assert_contains '- name: Cache Diagnostics After Restore' "workflow should log cache state after restore"
assert_contains '- name: Cache Diagnostics Before Save' "workflow should log cache state before save"
assert_contains '- name: Initialize Build Observability' "workflow should initialize build timing observability"
assert_contains 'echo "PREP_STAGE_START_TS=$(date +%s)" >> "$GITHUB_ENV"' "workflow should record the prep stage start timestamp"
assert_contains '- name: Report ccache Stats Before Build' "workflow should print ccache stats before compilation"
assert_contains '- name: Report ccache Stats After Build' "workflow should print ccache stats after compilation"
assert_contains 'ccache -s || true' "workflow should tolerate ccache stats collection failures"
assert_contains '【Lin】prep stage duration:' "workflow should log prep stage duration"
assert_contains '【Lin】download stage duration:' "workflow should log download stage duration"
assert_contains '【Lin】compile stage duration:' "workflow should log compile stage duration"
assert_not_contains '- name: Restore dl Cache' "workflow should not introduce dl cache in this change"
assert_not_contains '- name: Save dl Cache' "workflow should not introduce dl cache in this change"

echo "test_workflow_cache_keys: ok"
```

- [ ] **Step 2: Run the test to verify it fails for the current workflow**

Run:

```bash
rtk bash Scripts/tests/test_workflow_cache_keys.sh
```

Expected:

```text
ASSERT FAILED: workflow should restore toolchain cache explicitly
```

- [ ] **Step 3: Commit the red test change**

Run:

```bash
git add Scripts/tests/test_workflow_cache_keys.sh
git commit -m "test: require separated workflow cache steps"
```

Expected: a commit containing only the test update.

### Task 2: Convert The Workflow To Explicit Restore/Save Steps

**Files:**
- Modify: `/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CORE-ALL.yml:239-271`
- Test: `/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/tests/test_workflow_cache_keys.sh`

- [ ] **Step 1: Replace the existing cache steps with restore steps**

In `/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CORE-ALL.yml`, replace the current cache block starting at `- name: Check Toolchain Cache` with this restore section:

```yaml
    - name: Restore Toolchain Cache
      id: restore_toolchain_cache
      if: env.CACHE_TOOLCHAIN == 'true'
      uses: actions/cache/restore@v5
      with:
        key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}
        path: |
          ${{ env.OPENWRT_PATH }}/staging_dir/host*
          ${{ env.OPENWRT_PATH }}/staging_dir/tool*

    - name: Restore ccache Cache
      id: restore_ccache_cache
      if: env.CACHE_TOOLCHAIN == 'true'
      uses: actions/cache/restore@v5
      with:
        key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}
        restore-keys: |
          ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-
        path: |
          ${{ env.OPENWRT_PATH }}/.ccache
```

- [ ] **Step 2: Add post-restore diagnostics without changing cache behavior**

Immediately after the restore steps, insert this diagnostics step:

```yaml
    - name: Cache Diagnostics After Restore
      if: env.CACHE_TOOLCHAIN == 'true'
      run: |
        if [ -d "${{ env.OPENWRT_PATH }}/staging_dir" ]; then
          echo "【Lin】staging_dir restored"
        else
          echo "【Lin】staging_dir missing after restore"
        fi

        if [ -d "${{ env.OPENWRT_PATH }}/.ccache" ]; then
          echo "【Lin】.ccache restored"
          du -sh "${{ env.OPENWRT_PATH }}/.ccache"
        else
          echo "【Lin】.ccache missing after restore"
        fi
```

- [ ] **Step 3: Keep Refresh Cache Metadata in place after restore**

Leave the existing `Refresh Cache Metadata` step in the workflow, still after the restore steps and diagnostics step. The body should remain:

```yaml
    - name: Refresh Cache Metadata
      if: env.CACHE_TOOLCHAIN == 'true'
      run: |
        if [ -d "${{ env.OPENWRT_PATH }}/staging_dir" ]; then
          find "${{ env.OPENWRT_PATH }}/staging_dir" -type d -name "stamp" -not -path "*target*" | while read -r DIR; do
            find "$DIR" -type f -exec touch {} +
          done
          mkdir -p ${{ env.OPENWRT_PATH }}/tmp && echo "1" > ${{ env.OPENWRT_PATH }}/tmp/.build
          echo "【Lin】toolchain skiped done!"
        else
          echo "【Lin】caches missed!"
        fi
```

- [ ] **Step 4: Start build observability timing after Refresh Cache Metadata**

Immediately after `Refresh Cache Metadata`, initialize the start timestamp for the pre-download preparation phase:

```yaml
    - name: Initialize Build Observability
      run: |
        echo "PREP_STAGE_START_TS=$(date +%s)" >> "$GITHUB_ENV"
```

- [ ] **Step 5: Add ccache stats and stage timing logs around the build**

Update the download and build area so CI logs can show whether cache hits translated into actual savings:

```yaml
    - name: Download tools (下载工具包)
      working-directory: ${{ env.OPENWRT_PATH }}
      run: |
        prep_end_ts=$(date +%s)
        if [ -n "${PREP_STAGE_START_TS:-}" ]; then
          echo "【Lin】prep stage duration: $((prep_end_ts - PREP_STAGE_START_TS))s"
        else
          echo "【Lin】prep stage duration: unavailable"
        fi
        download_start_ts=$(date +%s)
        echo "【Lin】下载工具，DEVICE：${{ env.DEVICE_TARGET }}-${{ env.DEVICE_SUBTARGET }}-${{ env.DEVICE_PROFILE }}"
        make download -j$(nproc)
        download_end_ts=$(date +%s)
        echo "【Lin】download stage duration: $((download_end_ts - download_start_ts))s"

    - name: Report ccache Stats Before Build
      continue-on-error: true
      working-directory: ${{ env.OPENWRT_PATH }}
      run: |
        if command -v ccache >/dev/null 2>&1; then
          echo "【Lin】ccache stats before build"
          ccache -s || true
        else
          echo "【Lin】ccache command not found before build"
        fi

    - name: 编译固件 Build firmware
      id: compile
      continue-on-error: true
      working-directory: ${{ env.OPENWRT_PATH }}
      run: |
        compile_start_ts=$(date +%s)
        echo -e "$(nproc) thread build."
        make -j"$(nproc)" || make -j1 V=s
        compile_end_ts=$(date +%s)
        echo "【Lin】compile stage duration: $((compile_end_ts - compile_start_ts))s"

    - name: Report ccache Stats After Build
      if: always()
      continue-on-error: true
      working-directory: ${{ env.OPENWRT_PATH }}
      run: |
        if command -v ccache >/dev/null 2>&1; then
          echo "【Lin】ccache stats after build"
          ccache -s || true
        else
          echo "【Lin】ccache command not found after build"
        fi
```

- [ ] **Step 6: Add pre-save diagnostics and explicit save steps near the end of the job**

Insert the following block late in the job, after the build/output work is done but before cleanup removes build data:

```yaml
    - name: Cache Diagnostics Before Save
      if: always() && env.CACHE_TOOLCHAIN == 'true'
      run: |
        if [ -d "${{ env.OPENWRT_PATH }}/.ccache" ]; then
          echo "【Lin】.ccache before save"
          du -sh "${{ env.OPENWRT_PATH }}/.ccache"
        else
          echo "【Lin】.ccache missing before save"
        fi

        if compgen -G "${{ env.OPENWRT_PATH }}/staging_dir/host*" > /dev/null; then
          echo "【Lin】toolchain host cache present"
        else
          echo "【Lin】toolchain host cache missing before save"
        fi

        if compgen -G "${{ env.OPENWRT_PATH }}/staging_dir/tool*" > /dev/null; then
          echo "【Lin】toolchain tool cache present"
        else
          echo "【Lin】toolchain tool cache missing before save"
        fi

    - name: Save Toolchain Cache
      if: always() && env.CACHE_TOOLCHAIN == 'true' && hashFiles(format('{0}/staging_dir/host*', env.OPENWRT_PATH), format('{0}/staging_dir/tool*', env.OPENWRT_PATH)) != ''
      uses: actions/cache/save@v5
      with:
        key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}
        path: |
          ${{ env.OPENWRT_PATH }}/staging_dir/host*
          ${{ env.OPENWRT_PATH }}/staging_dir/tool*

    - name: Save ccache Cache
      if: always() && env.CACHE_TOOLCHAIN == 'true' && hashFiles(format('{0}/.ccache/**', env.OPENWRT_PATH)) != ''
      uses: actions/cache/save@v5
      with:
        key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}
        path: |
          ${{ env.OPENWRT_PATH }}/.ccache
```

If `hashFiles(format(...))` is not accepted in this workflow context, replace the `if:` conditions with step-level shell guards in a preceding metadata step that writes booleans to `$GITHUB_OUTPUT`, then gate the save steps on those outputs. Do not change the cache keys.

- [ ] **Step 7: Run the workflow cache test to verify it now passes**

Run:

```bash
rtk bash Scripts/tests/test_workflow_cache_keys.sh
```

Expected:

```text
test_workflow_cache_keys: ok
```

- [ ] **Step 8: Commit the workflow structure change**

Run:

```bash
git add .github/workflows/CORE-ALL.yml Scripts/tests/test_workflow_cache_keys.sh
git commit -m "refactor: split workflow cache restore and save"
```

Expected: a commit containing the workflow cache split and updated test.

### Task 3: Run Focused Verification And Record Follow-Up For dl

**Files:**
- Modify: none
- Test: `/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/tests/test_workflow_cache_keys.sh`
- Reference: `/Users/lin/Documents/Git/Linjw/LjwOpenWrt/docs/superpowers/specs/2026-04-23-cache-restore-save-separation-design.md`

- [ ] **Step 1: Re-run the focused cache workflow test**

Run:

```bash
rtk bash Scripts/tests/test_workflow_cache_keys.sh
```

Expected:

```text
test_workflow_cache_keys: ok
```

- [ ] **Step 2: Run the nearby workflow regression tests that touch this area**

Run:

```bash
rtk bash Scripts/tests/test_core_all_precompile_notify.sh
rtk bash Scripts/tests/test_core_all_build_keepalive.sh
```

Expected:

```text
test_core_all_precompile_notify: ok
test_core_all_build_keepalive: ok
```

- [ ] **Step 3: Review the final diff to confirm scope stayed narrow**

Run:

```bash
rtk git diff -- .github/workflows/CORE-ALL.yml Scripts/tests/test_workflow_cache_keys.sh
```

Expected:

```text
Only the cache step structure, cache diagnostics, and the workflow cache test changed.
```

- [ ] **Step 4: Commit the verification pass**

Run:

```bash
git add .github/workflows/CORE-ALL.yml Scripts/tests/test_workflow_cache_keys.sh
git commit -m "test: verify workflow cache split behavior"
```

Expected: no-op if the previous commit already contains the final verified state; otherwise a small follow-up commit.

- [ ] **Step 5: Capture the dl decision as a post-implementation observation**

After the code change lands and CI has run at least twice, inspect the logs and answer these two questions before proposing `dl` cache work:

```text
1. Does `make download` still consume enough wall time to matter after cache restore/save separation is stable?
2. Is the main bottleneck still the compile step rather than the download step?
```

If the answer is “compile is still the dominant cost,” do not add `dl` cache yet.
