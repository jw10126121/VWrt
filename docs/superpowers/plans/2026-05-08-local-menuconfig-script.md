# Local Menuconfig Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local helper script that applies this repository's parameterized OpenWrt configuration onto `/Volumes/OpenWrt/lede` and then opens `menuconfig` using inputs aligned with `DEFAULT.yml`.

**Architecture:** Introduce a single shell entrypoint in `Scripts/` that mirrors the CI sequence locally by deriving environment defaults, validating required inputs, exporting the merged `.config`, and optionally entering `menuconfig`. Add one shell test that locks the script interface and key execution stages without requiring an actual OpenWrt tree.

**Tech Stack:** POSIX shell / bash, existing repository shell scripts, grep-based shell tests.

---

### Task 1: Lock the script contract with a failing test

**Files:**
- Create: `Scripts/tests/test_local_menuconfig.sh`
- Test: `Scripts/tests/test_local_menuconfig.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TARGET_SCRIPT="$SCRIPT_DIR/local_menuconfig.sh"

test -f "$TARGET_SCRIPT"
grep -Fq 'OPENWRT_PATH=${OPENWRT_PATH:-/Volumes/OpenWrt/lede}' "$TARGET_SCRIPT"
grep -Fq 'WRT_DIY_FEEDS=${WRT_DIY_FEEDS:-diy_feeds.sh}' "$TARGET_SCRIPT"
grep -Fq 'LOCAL_SKIP_MENUCONFIG=${LOCAL_SKIP_MENUCONFIG:-false}' "$TARGET_SCRIPT"
grep -Fq 'git fetch --depth=1 origin "${WRT_SOURCE_HASH_INFO}"' "$TARGET_SCRIPT"
grep -Fq 'bash "$SCRIPT_ROOT/$WRT_DIY_FEEDS"' "$TARGET_SCRIPT"
grep -Fq 'bash "$SCRIPT_ROOT/export_config.sh" "${EXPORT_ARGS[@]}"' "$TARGET_SCRIPT"
grep -Fq 'make menuconfig' "$TARGET_SCRIPT"
grep -Fq './scripts/diffconfig.sh > seed.config' "$TARGET_SCRIPT"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash Scripts/tests/test_local_menuconfig.sh`
Expected: fail at `test -f "$TARGET_SCRIPT"` because `Scripts/local_menuconfig.sh` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```bash
#!/bin/bash
set -eu

OPENWRT_PATH=${OPENWRT_PATH:-/Volumes/OpenWrt/lede}
WRT_DIY_FEEDS=${WRT_DIY_FEEDS:-diy_feeds.sh}
LOCAL_SKIP_MENUCONFIG=${LOCAL_SKIP_MENUCONFIG:-false}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash Scripts/tests/test_local_menuconfig.sh`
Expected: pass with `test_local_menuconfig: ok`.

### Task 2: Implement the local workflow wrapper

**Files:**
- Create: `Scripts/local_menuconfig.sh`
- Modify: `Scripts/tests/test_local_menuconfig.sh`

- [ ] **Step 1: Implement required defaults and validation**

```bash
OPENWRT_PATH=${OPENWRT_PATH:-/Volumes/OpenWrt/lede}
WRT_OVERLAYS=${WRT_OVERLAYS:-}
WRT_LUCI_BRANCH=${WRT_LUCI_BRANCH:-}
WRT_DIY_SETTING=${WRT_DIY_SETTING:-diy_config.sh}
WRT_DIYPackages=${WRT_DIYPackages:-Packages.sh}
WRT_DIY_FEEDS=${WRT_DIY_FEEDS:-diy_feeds.sh}
WRT_DEFAULT_LANIP=${WRT_DEFAULT_LANIP:-192.168.0.1}
WRT_SOURCE_HASH_INFO=${WRT_SOURCE_HASH_INFO:-}
WRT_THEME_NAME=${WRT_THEME_NAME:-argon}
IS_RESET_PASSWORD=${IS_RESET_PASSWORD:-true}
LOCAL_SKIP_MENUCONFIG=${LOCAL_SKIP_MENUCONFIG:-false}
```

- [ ] **Step 2: Implement the CI-like execution order**

```bash
bash "$SCRIPT_ROOT/$WRT_DIY_FEEDS"
./scripts/feeds update -a
./scripts/feeds install -a
bash "$SCRIPT_ROOT/$WRT_DIYPackages"
bash "$SCRIPT_ROOT/export_config.sh" "${EXPORT_ARGS[@]}"
bash "$SCRIPT_ROOT/$WRT_DIY_SETTING" ...
make defconfig
bash "$SCRIPT_ROOT/diy_after_defconfig.sh"
```

- [ ] **Step 3: Implement the interactive tail**

```bash
if [ "$LOCAL_SKIP_MENUCONFIG" != 'true' ]; then
    make menuconfig
fi
make defconfig
./scripts/diffconfig.sh > seed.config
```

- [ ] **Step 4: Re-run the script contract test**

Run: `bash Scripts/tests/test_local_menuconfig.sh`
Expected: pass with `test_local_menuconfig: ok`.

### Task 3: Verify no regressions in adjacent shell behavior

**Files:**
- Test: `Scripts/tests/test_local_menuconfig.sh`
- Test: `Scripts/tests/test_export_config_parameterized.sh`
- Test: `Scripts/tests/test_workflow_luci_branch_input.sh`

- [ ] **Step 1: Run the new focused test**

Run: `bash Scripts/tests/test_local_menuconfig.sh`
Expected: `test_local_menuconfig: ok`

- [ ] **Step 2: Run adjacent existing tests**

Run: `bash Scripts/tests/test_export_config_parameterized.sh`
Expected: `test_export_config_parameterized: ok`

Run: `bash Scripts/tests/test_workflow_luci_branch_input.sh`
Expected: `test_workflow_luci_branch_input: ok`

- [ ] **Step 3: Inspect git diff**

Run: `git diff -- Scripts/local_menuconfig.sh Scripts/tests/test_local_menuconfig.sh docs/superpowers/plans/2026-05-08-local-menuconfig-script.md`
Expected: only the new helper script, its test, and the plan document are changed.
