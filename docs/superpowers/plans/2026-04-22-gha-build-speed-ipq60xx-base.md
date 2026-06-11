# GHA Build Speed (IPQ60XX Base) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce repeated GitHub Actions build overhead for `lean-IPQ60XX-NOWIFI-fw3-base` by trimming setup work, adding `dl/` caching, and surfacing ccache and stage timing data without expanding cache risk for heavier jobs like `GL-MT6000-WIFI`.

**Architecture:** Keep the optimization inside the shared workflow at `.github/workflows/CORE-ALL.yml`, but constrain every new cache and log behavior with conservative keys and caps that remain safe for heavier filogic builds. Drive the change through shell-based workflow assertions first, then make the smallest workflow edit set that satisfies those tests.

**Tech Stack:** GitHub Actions YAML, Bash, existing repository shell test scripts

---

### Task 1: Lock The New Workflow Contract In Tests

**Files:**
- Modify: `.github/workflows/CORE-ALL.yml`
- Modify: `Scripts/test_workflow_cache_keys.sh`
- Create: `Scripts/test_workflow_build_speed_guardrails.sh`

- [ ] **Step 1: Write the failing workflow guardrail test**

Create `Scripts/test_workflow_build_speed_guardrails.sh` with assertions for the new behavior:

```bash
#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

assert_not_contains 'apt -yqq full-upgrade' "workflow should not upgrade the entire runner image"
assert_contains '- name: Check Download Cache' "workflow should restore dl cache"
assert_contains '${{ env.OPENWRT_PATH }}/dl' "workflow should cache the dl directory"
assert_contains 'ccache -M 1.5G' "workflow should cap ccache size conservatively"
assert_contains 'ccache -s || true' "workflow should print ccache statistics"
assert_contains 'DOWNLOAD_START=$(date +%s)' "workflow should record download timing"
assert_contains 'BUILD_START=$(date +%s)' "workflow should record compile timing"
assert_contains 'du -sh dl .ccache build_dir staging_dir tmp 2>/dev/null || true' "workflow should summarize key directory sizes"

echo "test_workflow_build_speed_guardrails: ok"
```

- [ ] **Step 2: Run the new guardrail test to verify it fails**

Run: `bash Scripts/test_workflow_build_speed_guardrails.sh`

Expected: FAIL because `CORE-ALL.yml` does not yet contain the new `dl` cache step, ccache cap, or timing output.

- [ ] **Step 3: Extend the existing cache-key test with dl-cache assertions**

Add these assertions near the existing cache checks in `Scripts/test_workflow_cache_keys.sh`:

```bash
assert_contains '- name: Check Download Cache' "workflow should define a download cache step"
assert_contains 'key: dl-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}-${{ env.BUILD_VARIANT_TAG }}' "download cache key should include source commit and variant tag"
assert_contains 'dl-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-' "download cache should allow same-platform restore fallback"
```

- [ ] **Step 4: Run the cache-key test to verify it fails for the new expectations**

Run: `bash Scripts/test_workflow_cache_keys.sh`

Expected: FAIL because the workflow does not yet define the `dl` cache key.

- [ ] **Step 5: Commit the red tests**

```bash
git add Scripts/test_workflow_cache_keys.sh Scripts/test_workflow_build_speed_guardrails.sh
git commit -m "test: add workflow build speed guardrails"
```

### Task 2: Implement Conservative Cache And Setup Changes

**Files:**
- Modify: `.github/workflows/CORE-ALL.yml`
- Test: `Scripts/test_workflow_cache_keys.sh`
- Test: `Scripts/test_workflow_build_speed_guardrails.sh`

- [ ] **Step 1: Remove expensive runner-maintenance commands from initialization**

Change the `Initialization Environment` shell block in `.github/workflows/CORE-ALL.yml` from:

```bash
sudo -E apt -yqq update
sudo -E apt -yqq full-upgrade
sudo -E apt -yqq autoremove --purge
sudo -E apt -yqq autoclean
sudo -E apt -yqq clean
sudo -E apt -yqq install dos2unix libfuse-dev
```

to:

```bash
sudo -E apt -yqq update
sudo -E apt -yqq install dos2unix libfuse-dev
```

- [ ] **Step 2: Add a download cache step after the existing ccache restore**

Insert a new cache step in `.github/workflows/CORE-ALL.yml` after `Check ccache Cache`:

```yaml
    - name: Check Download Cache
      id: check_download_cache
      if: env.CACHE_TOOLCHAIN == 'true'
      uses: actions/cache@v5
      with:
        key: dl-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}-${{ env.BUILD_VARIANT_TAG }}
        restore-keys: |
          dl-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-
        path: |
          ${{ env.OPENWRT_PATH }}/dl
```

- [ ] **Step 3: Add conservative ccache controls and logging**

Insert a dedicated ccache reporting step after `Refresh Cache Metadata`:

```yaml
    - name: Report ccache Before Build
      if: env.CACHE_TOOLCHAIN == 'true'
      working-directory: ${{ env.OPENWRT_PATH }}
      run: |
        ccache -M 1.5G || true
        ccache -s || true
```

- [ ] **Step 4: Re-run the tests to verify they now pass**

Run:

```bash
bash Scripts/test_workflow_cache_keys.sh
bash Scripts/test_workflow_build_speed_guardrails.sh
```

Expected: both scripts print `ok`.

- [ ] **Step 5: Commit the cache and setup implementation**

```bash
git add .github/workflows/CORE-ALL.yml Scripts/test_workflow_cache_keys.sh Scripts/test_workflow_build_speed_guardrails.sh
git commit -m "feat: add conservative workflow download cache"
```

### Task 3: Add Timing And Directory-Size Observability

**Files:**
- Modify: `.github/workflows/CORE-ALL.yml`
- Modify: `Scripts/test_workflow_build_speed_guardrails.sh`

- [ ] **Step 1: Extend the guardrail test with post-build observability expectations**

Ensure `Scripts/test_workflow_build_speed_guardrails.sh` contains these assertions:

```bash
assert_contains 'DOWNLOAD_START=$(date +%s)' "workflow should record download timing"
assert_contains 'DOWNLOAD_END=$(date +%s)' "workflow should record download completion time"
assert_contains 'echo "【Lin】download耗时：$((DOWNLOAD_END - DOWNLOAD_START))s"' "workflow should report download duration"
assert_contains 'BUILD_START=$(date +%s)' "workflow should record compile timing"
assert_contains 'BUILD_END=$(date +%s)' "workflow should record compile completion time"
assert_contains 'echo "【Lin】compile耗时：$((BUILD_END - BUILD_START))s"' "workflow should report compile duration"
assert_contains 'du -sh dl .ccache build_dir staging_dir tmp 2>/dev/null || true' "workflow should summarize key directory sizes"
assert_contains '- name: Report ccache After Build' "workflow should report ccache after compile"
```

- [ ] **Step 2: Run the guardrail test to verify the new assertions fail**

Run: `bash Scripts/test_workflow_build_speed_guardrails.sh`

Expected: FAIL because timing and post-build reporting are not implemented yet.

- [ ] **Step 3: Add timing and size summaries around download and compile**

Update the `Download tools (下载工具包)` block in `.github/workflows/CORE-ALL.yml` to:

```bash
echo "【Lin】下载工具，DEVICE：${{ env.DEVICE_TARGET }}-${{ env.DEVICE_SUBTARGET }}-${{ env.DEVICE_PROFILE }}"
DOWNLOAD_START=$(date +%s)
make download -j$(nproc)
DOWNLOAD_END=$(date +%s)
echo "【Lin】download耗时：$((DOWNLOAD_END - DOWNLOAD_START))s"
du -sh dl .ccache build_dir staging_dir tmp 2>/dev/null || true
```

Update the `编译固件 Build firmware` block to:

```bash
echo -e "$(nproc) thread build."
BUILD_START=$(date +%s)
make -j$(nproc) || make -j1 V=s
BUILD_END=$(date +%s)
echo "【Lin】compile耗时：$((BUILD_END - BUILD_START))s"
du -sh dl .ccache build_dir staging_dir tmp 2>/dev/null || true
```

Add a new step after `Finalize Compile Status`:

```yaml
    - name: Report ccache After Build
      if: always() && env.CACHE_TOOLCHAIN == 'true'
      working-directory: ${{ env.OPENWRT_PATH }}
      run: |
        ccache -s || true
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```bash
bash Scripts/test_workflow_cache_keys.sh
bash Scripts/test_workflow_build_speed_guardrails.sh
```

Expected: both scripts print `ok`.

- [ ] **Step 5: Commit the observability changes**

```bash
git add .github/workflows/CORE-ALL.yml Scripts/test_workflow_build_speed_guardrails.sh
git commit -m "feat: add workflow build timing visibility"
```

### Task 4: Final Verification For This Iteration

**Files:**
- Modify: `.github/workflows/CORE-ALL.yml`
- Modify: `Scripts/test_workflow_cache_keys.sh`
- Modify: `Scripts/test_workflow_build_speed_guardrails.sh`

- [ ] **Step 1: Run the full local verification set**

Run:

```bash
bash Scripts/test_workflow_cache_keys.sh
bash Scripts/test_workflow_build_speed_guardrails.sh
```

Expected:

- `test_workflow_cache_keys: ok`
- `test_workflow_build_speed_guardrails: ok`

- [ ] **Step 2: Re-read the workflow diff against the spec**

Check that `.github/workflows/CORE-ALL.yml` now satisfies the approved design:

```bash
git diff -- .github/workflows/CORE-ALL.yml Scripts/test_workflow_cache_keys.sh Scripts/test_workflow_build_speed_guardrails.sh
```

Expected:

- `apt full-upgrade` removed
- new `dl` cache present with conservative key
- ccache capped at `1.5G`
- ccache stats emitted before and after compile
- download and compile timing emitted
- key directory sizes emitted

- [ ] **Step 3: Commit any final cleanup**

```bash
git add .github/workflows/CORE-ALL.yml Scripts/test_workflow_cache_keys.sh Scripts/test_workflow_build_speed_guardrails.sh
git commit -m "chore: finalize workflow build speed optimization"
```
