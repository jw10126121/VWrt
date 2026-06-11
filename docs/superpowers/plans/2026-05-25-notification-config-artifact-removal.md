# 编译通知与配置 Artifact 收敛 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除编译前配置快照与配置 Artifact 上传链路，修复完成通知中重复的 `编译开始`，并保持插件清单与下载地址展示不变。

**Architecture:** 保留编译结束后的 `ci_organize_outputs.sh` 作为最终说明文件生成入口，让 `ci_create_notifications.sh` 只依赖结束阶段产出的说明文件或 `system_content` 回退值。同步精简 `CORE-ALL.yml` 中编译前的配置快照步骤，并用 shell 测试锁定通知格式与 workflow 步骤变化。

**Tech Stack:** GitHub Actions YAML, POSIX shell scripts, repository shell tests

---

### Task 1: Lock In The New Workflow Shape

**Files:**
- Modify: `scripts/tests/test_notification_format.sh`
- Create: `scripts/tests/test_core_all_notification_config_cleanup.sh`
- Test: `scripts/tests/test_notification_format.sh`
- Test: `scripts/tests/test_core_all_notification_config_cleanup.sh`

- [ ] **Step 1: Extend notification tests to assert the new source priority**

Add a success-path case that feeds `release_desc_file` instead of `readme_desc_file` / `system_content_note`, and assert:

```bash
grep -q 'Artifact下载地址：https://github.com/user/repo/actions/runs/123456' "$ENV_FILE"
grep -q '编译状态：success' "$ENV_FILE"
grep -q '^编译结束：D260418_T120000$' "$ENV_FILE"
[ "$(grep -c '^编译开始：D260418_T105727$' "$ENV_FILE")" -eq 1 ]
if grep -q 'system_content_note' "$ENV_FILE"; then
	echo "system_content_note should not be required in success notification" >&2
	exit 1
fi
```

- [ ] **Step 2: Add a workflow regression test for config upload removal**

Create `scripts/tests/test_core_all_notification_config_cleanup.sh`:

```bash
#!/bin/bash

set -eu

workflow=".github/workflows/CORE-ALL.yml"

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq "$pattern" "$workflow"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq "$pattern" "$workflow"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains 'Upload Config (上传配置文件)' 'CORE-ALL should no longer upload config artifacts before compile'
assert_not_contains 'system_content_note' 'CORE-ALL should no longer persist pre-compile notification snapshots'
assert_not_contains 'readme_desc_file=' 'CORE-ALL should no longer prepare pre-compile readme snapshot paths'
assert_contains 'Create Notification Content (创建推送结果内容)' 'CORE-ALL should still generate final notification content'

echo "test_core_all_notification_config_cleanup: ok"
```

- [ ] **Step 3: Run the new tests and confirm they fail before implementation**

Run:

```bash
rtk bash scripts/tests/test_notification_format.sh
rtk bash scripts/tests/test_core_all_notification_config_cleanup.sh
```

Expected:

- `test_notification_format.sh` fails because success notification still depends on `system_content_note` / `readme_desc_file` and duplicates `编译开始`
- `test_core_all_notification_config_cleanup.sh` fails because `CORE-ALL.yml` still contains config snapshot/upload logic

### Task 2: Remove Pre-Compile Snapshot Coupling

**Files:**
- Modify: `.github/workflows/CORE-ALL.yml`

- [ ] **Step 1: Remove the pre-compile config snapshot/export block**

Delete from `Check Config (缓存配置文件)` everything related to:

```yaml
mkdir -p ./config_mine
cp -f ./my_config.txt ./config_mine/${name_config_file}_mine.txt
cp -f ./.config ./config_mine/"$name_config_file"_full.txt
awk '!/^#/ && !/^$/' ./.config > ./config_mine/"$name_config_file".txt
cp -f ./seed.config ./config_mine/"$name_config_file".seed.txt
readme_script="$GITHUB_WORKSPACE/$WRT_DIR_SCRIPTS/readme.sh"
TO_MY_SAY_DETAIL=$(printf '%s\n\n编译开始：%s\n' "${system_content}" "${{ env.START_TIME }}")
[ -f "$readme_script" ] && bash "$readme_script" -c "./.config" -o "./config_mine/readme.txt" -s "$TO_MY_SAY_DETAIL" -a "${{ env.WRT_MINE_SAY }}" -r 'false'
readme_desc_file="$OPENWRT_PATH/config_mine/readme.txt"
echo "readme_desc_file=$readme_desc_file" >> $GITHUB_ENV
echo 'system_content_note<<EOF' >> $GITHUB_ENV
cat "${readme_desc_file}" >> $GITHUB_ENV
echo 'EOF' >> $GITHUB_ENV
```

Keep only the metadata-safe parts that are still needed later, or remove the whole step if no longer necessary.

- [ ] **Step 2: Remove the config artifact upload step**

Delete this workflow step entirely:

```yaml
- name: Upload Config (上传配置文件)
  id: config_upload
  timeout-minutes: 5
  continue-on-error: true
  uses: actions/upload-artifact@v6.0.0
  with:
    name: config_${{ env.OUTPUT_NAME_PREFIX }}
    path: ${{ env.OPENWRT_PATH }}/config_mine
```

- [ ] **Step 3: Remove obsolete workflow env defaults if they become unused**

Delete stale entries such as:

```yaml
system_content_note: ''
readme_desc_file: ''
```

Preserve `release_desc_file` because the final notification and release publishing still need it.

### Task 3: Switch Final Notification To End-Stage Outputs

**Files:**
- Modify: `scripts/ci_create_notifications.sh`

- [ ] **Step 1: Change notify body source priority**

Make `get_notify_body()` prefer the final release/readme outputs only:

```bash
if [ -n "${release_desc_file:-}" ] && [ -f "${release_desc_file}" ]; then
	cat "${release_desc_file}"
	return 0
fi

if [ -n "${readme_desc_file:-}" ] && [ -f "${readme_desc_file}" ]; then
	cat "${readme_desc_file}"
	return 0
fi

printf '%s\n' "${system_content:-}"
```

Do not read `system_content_note`.

- [ ] **Step 2: Remove the extra compile-start append**

Delete the tail append:

```bash
echo "编译开始：${START_TIME}"
```

Keep:

```bash
echo "编译状态：${COMPILE_STATUS:-unknown}"
echo "编译结束：${END_TIME:-}"
```

This keeps one `编译开始` from the rendered body and avoids the duplicate line.

- [ ] **Step 3: Re-run the targeted tests**

Run:

```bash
rtk bash scripts/tests/test_notification_format.sh
rtk bash scripts/tests/test_core_all_notification_config_cleanup.sh
```

Expected: both PASS.

### Task 4: Verify Related Output Paths Still Hold

**Files:**
- Modify: `scripts/tests/test_ci_organize_outputs_naming.sh` (only if current coverage misses the needed output path contract)
- Test: `scripts/tests/test_ci_organize_outputs_naming.sh`

- [ ] **Step 1: Inspect whether organize-output coverage already guarantees `release_desc_file` and `readme_desc_file` emission**

If existing coverage is enough, make no change. Otherwise add assertions like:

```bash
grep -q '^release_desc_file='"$OPENWRT_PATH"'/readme_release.txt$' "$ENV_FILE"
grep -q '^readme_desc_file='"$OPENWRT_PATH"'/config_mine/readme.txt$' "$ENV_FILE"
```

- [ ] **Step 2: Run the organize-output regression test if touched or needed for confidence**

Run:

```bash
rtk bash scripts/tests/test_ci_organize_outputs_naming.sh
```

Expected: PASS.

### Task 5: Final Verification

**Files:**
- Verify only

- [ ] **Step 1: Run the complete targeted verification set**

Run:

```bash
rtk bash scripts/tests/test_notification_format.sh
rtk bash scripts/tests/test_core_all_notification_config_cleanup.sh
rtk bash scripts/tests/test_ci_organize_outputs_naming.sh
```

Expected: all PASS.

- [ ] **Step 2: Review the final diff for scope control**

Run:

```bash
rtk git diff -- .github/workflows/CORE-ALL.yml scripts/ci_create_notifications.sh scripts/tests/test_notification_format.sh scripts/tests/test_core_all_notification_config_cleanup.sh scripts/tests/test_ci_organize_outputs_naming.sh
```

Confirm the diff only contains:

- pre-compile config snapshot removal
- config artifact upload removal
- final notification body source cleanup
- regression test updates
