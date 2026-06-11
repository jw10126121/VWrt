# FW3/FW4 Overlay 配置管理 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 FW3/FW4 双文件维护改为 FW3 基线 + FW4 覆盖文件模式，减少配置重复。

**架构：** FW3 文件去掉 `-FW3` 后缀作为基线，FW4 文件只保留差异行。构建时 `--fw fw3` 直接用基线，`--fw fw4` 在基线后追加覆盖文件。`export_config.sh` 的 `resolve_device_config()` 统一查找基线文件。

**技术栈：** Bash shell 脚本，OpenWrt `.config` 格式（后定义覆盖前定义）

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 修改 | `Scripts/export_config.sh` | 重写 `resolve_device_config()`，主流程追加 FW4 overlay |
| 修改 | `Scripts/tests/test_export_config.sh` | 适配新行为 |
| 修改 | `Scripts/tests/test_export_config_prefers_direct_fw4_file.sh` | 适配新行为 |
| 新增 | `Scripts/tests/test_export_config_fw4_overlay.sh` | 测试 FW4 overlay 覆盖机制 |
| 重命名 | `Config/CMIOT-AX18-NOWIFI-FW3.txt` → `Config/CMIOT-AX18-NOWIFI.txt` | 基线 |
| 重写 | `Config/CMIOT-AX18-NOWIFI-FW4.txt` | 纯覆盖文件 |
| 重命名 | `Config/JD-AX1800PRO-WIFI-FW3.txt` → `Config/JD-AX1800PRO-WIFI.txt` | 基线 |
| 重写 | `Config/JD-AX1800PRO-WIFI-FW4.txt` | 纯覆盖文件 |
| 重命名 | `Config/JD-AX1800PRO-NOWIFI-FW3.txt` → `Config/JD-AX1800PRO-NOWIFI.txt` | 基线 |
| 重写 | `Config/JD-AX1800PRO-NOWIFI-FW4.txt` | 纯覆盖文件 |
| 重命名 | `Config/JD-AX6600-WIFI-FW3.txt` → `Config/JD-AX6600-WIFI.txt` | 基线 |
| 重写 | `Config/JD-AX6600-WIFI-FW4.txt` | 纯覆盖文件 |
| 重命名 | `Config/MIR3G-WIFI-MINI-FW3.txt` → `Config/MIR3G-WIFI-MINI.txt` | 基线（无 FW4） |
| 重命名 | `Config/GL-MT6000-WIFI-FW3.txt` → `Config/GL-MT6000-WIFI.txt` | 基线（无 FW4） |

---

### 任务 1：为 export_config.sh 新行为编写测试

**文件：**
- 新增：`Scripts/tests/test_export_config_fw4_overlay.sh`

- [ ] **步骤 1：编写 FW4 overlay 测试**

```bash
#!/bin/bash

# 说明：验证 --fw fw4 时，脚本使用 {device}.txt 作为基线，
# 并追加 {device}-FW4.txt 作为覆盖。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/device-overlays"

# 基线配置（模拟 FW3 完整文件）
cat > "$TMPDIR/DEVICE-X.txt" <<'EOF'
CONFIG_GENERAL_MARKER=y
CONFIG_DEVICE_BASE=y
CONFIG_FIREWALL=iptables
CONFIG_PROXY=ssrplus
CONFIG_PLUGIN_A=y
CONFIG_PLUGIN_B=m
EOF

# FW4 覆盖文件（只含差异行）
cat > "$TMPDIR/DEVICE-X-FW4.txt" <<'EOF'
# --- 防火墙栈切换 ---
CONFIG_FIREWALL=nftables

# --- 代理插件切换 ---
CONFIG_PROXY=homeproxy

# --- 插件状态切换 ---
CONFIG_PLUGIN_A=m
CONFIG_PLUGIN_B=y
EOF

# 测试 1：--fw fw3 不应包含 FW4 覆盖内容
FW3_OUT="$TMPDIR/fw3.txt"
bash "$EXPORT_SCRIPT" \
    --config-dir "$TMPDIR" \
    --device "DEVICE-X" \
    --fw "fw3" \
    --output "$FW3_OUT" >/dev/null

grep -q '^CONFIG_GENERAL_MARKER=y$' "$FW3_OUT"
grep -q '^CONFIG_FIREWALL=iptables$' "$FW3_OUT"
grep -q '^CONFIG_PROXY=ssrplus$' "$FW3_OUT"
grep -q '^CONFIG_PLUGIN_A=y$' "$FW3_OUT"
grep -q '^CONFIG_PLUGIN_B=m$' "$FW3_OUT"

# 测试 2：--fw fw4 应包含基线 + FW4 覆盖
FW4_OUT="$TMPDIR/fw4.txt"
bash "$EXPORT_SCRIPT" \
    --config-dir "$TMPDIR" \
    --device "DEVICE-X" \
    --fw "fw4" \
    --output "$FW4_OUT" >/dev/null

grep -q '^CONFIG_GENERAL_MARKER=y$' "$FW4_OUT"
grep -q '^CONFIG_DEVICE_BASE=y$' "$FW4_OUT"
# FW4 覆盖应生效
grep -n '^CONFIG_FIREWALL=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_FIREWALL=nftables'
grep -n '^CONFIG_PROXY=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PROXY=homeproxy'
grep -n '^CONFIG_PLUGIN_A=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PLUGIN_A=m'
grep -n '^CONFIG_PLUGIN_B=' "$FW4_OUT" | tail -n 1 | grep -q 'CONFIG_PLUGIN_B=y'

# 测试 3：无 FW4 覆盖文件时，--fw fw4 应正常工作（只是没有覆盖）
cat > "$TMPDIR/DEVICE-Y.txt" <<'EOF'
CONFIG_ONLY_BASE=y
EOF

FW4_NO_OVERLAY="$TMPDIR/fw4-no-overlay.txt"
bash "$EXPORT_SCRIPT" \
    --config-dir "$TMPDIR" \
    --device "DEVICE-Y" \
    --fw "fw4" \
    --output "$FW4_NO_OVERLAY" >/dev/null

grep -q '^CONFIG_ONLY_BASE=y$' "$FW4_NO_OVERLAY"

echo "test_export_config_fw4_overlay: ok"
```

- [ ] **步骤 2：运行测试验证失败**

运行：`bash Scripts/tests/test_export_config_fw4_overlay.sh`
预期：FAIL，因为当前 `resolve_device_config()` 还在按旧逻辑查找 `-FW4.txt` 作为独立文件

- [ ] **步骤 3：Commit 测试文件**

```bash
git add Scripts/tests/test_export_config_fw4_overlay.sh
git commit -m "test(配置导出): 添加 FW4 overlay 覆盖机制测试"
```

---

### 任务 2：修改 export_config.sh

**文件：**
- 修改：`Scripts/export_config.sh:23-44`（resolve_device_config）
- 修改：`Scripts/export_config.sh:217-249`（主流程）

- [ ] **步骤 1：重写 resolve_device_config()**

将 `Scripts/export_config.sh` 第 23-44 行替换为：

```bash
resolve_device_config() {
	local config_root=$1
	local device_name=$2

	# 优先查找无后缀的基线文件
	if [ -f "$config_root/${device_name}.txt" ]; then
		printf '%s\n' "${device_name}.txt"
		return 0
	fi

	# 兼容旧文件名（过渡期，迁移完成后可移除）
	if [ -f "$config_root/${device_name}-FW3.txt" ]; then
		printf '%s\n' "${device_name}-FW3.txt"
		return 0
	fi

	return 1
}
```

- [ ] **步骤 2：修改主流程中的设备配置查找和 FW4 overlay 追加**

将 `Scripts/export_config.sh` 第 217-249 行替换为：

```bash
device_config=$(resolve_device_config "$config_dir" "$device" || true)
if [ -z "$device_config" ]; then
	echo "缺少设备配置：$config_dir/${device}.txt 或 $config_dir/${device}-FW3.txt" >&2
	exit 1
fi

resolved_general_configs='GENERAL.txt'
device_config_path="$config_dir/$device_config"
processed_device_config="$device_config_path"
embeds_fw_stack=false
embeds_service_layer=false

if device_config_embeds_fw_stack "$device_config_path"; then
	embeds_fw_stack=true
fi

if device_config_embeds_service_layer "$device_config_path"; then
	embeds_service_layer=true
fi

if [ "$embeds_fw_stack" = true ] || [ "$embeds_service_layer" = true ]; then
	processed_device_config=$(mktemp)
	cleanup_files="$processed_device_config"
	preprocess_device_config "$device_config_path" "$fw" "$processed_device_config"
fi

device_overlay_config="device-overlays/${device}-$(printf '%s' "$fw" | tr '[:lower:]' '[:upper:]').txt"

bash "$MERGE_SCRIPT" \
	"$config_dir" \
	"$resolved_general_configs" \
	"$processed_device_config" \
	"$output_config"

if [ -f "$config_dir/$device_overlay_config" ]; then
	cat "$config_dir/$device_overlay_config" >> "$output_config"
fi

# --fw fw4 时追加 FW4 overlay 覆盖文件
if [ "${fw}" = "fw4" ] || [ "${fw}" = "FW4" ]; then
	fw4_overlay="${device}-FW4.txt"
	if [ -f "$config_dir/$fw4_overlay" ]; then
		cat "$config_dir/$fw4_overlay" >> "$output_config"
	fi
fi
```

- [ ] **步骤 3：运行测试验证通过**

运行：`bash Scripts/tests/test_export_config_fw4_overlay.sh`
预期：PASS

运行：`bash Scripts/tests/test_export_config.sh`
预期：PASS（现有测试仍兼容）

- [ ] **步骤 4：Commit**

```bash
git add Scripts/export_config.sh
git commit -m "refactor(配置导出): 重写 resolve_device_config 支持 FW4 overlay 模式"
```

---

### 任务 3：迁移 CMIOT-AX18-NOWIFI（主维护设备，首批验证）

**文件：**
- 重命名：`Config/CMIOT-AX18-NOWIFI-FW3.txt` → `Config/CMIOT-AX18-NOWIFI.txt`
- 重写：`Config/CMIOT-AX18-NOWIFI-FW4.txt`

- [ ] **步骤 1：导出旧方式的 FW3 和 FW4 结果作为基准**

```bash
# 保存旧脚本的导出结果（用 git stash 前的版本）
# 先用当前脚本导出（此时旧文件名还在）
bash Scripts/export_config.sh \
    --device CMIOT-AX18-NOWIFI --fw fw3 \
    --output /tmp/cmiot-old-fw3.txt

bash Scripts/export_config.sh \
    --device CMIOT-AX18-NOWIFI --fw fw4 \
    --output /tmp/cmiot-old-fw4.txt
```

- [ ] **步骤 2：重命名 FW3 文件为基线**

```bash
git mv Config/CMIOT-AX18-NOWIFI-FW3.txt Config/CMIOT-AX18-NOWIFI.txt
```

- [ ] **步骤 3：用 diff 生成 FW4 覆盖文件**

```bash
# 提取 FW4 与 FW3 的差异行（纯 CONFIG_ 行，忽略注释头和空行）
diff Config/CMIOT-AX18-NOWIFI.txt Config/CMIOT-AX18-NOWIFI-FW4.txt | \
    grep '^>' | sed 's/^> //' | \
    grep -E '^CONFIG_|^# ' > /tmp/cmiot-fw4-diff.txt

cat /tmp/cmiot-fw4-diff.txt
```

- [ ] **步骤 4：审查差异内容，确认无误后重写 FW4 文件**

将 `/tmp/cmiot-fw4-diff.txt` 的内容写入 `Config/CMIOT-AX18-NOWIFI-FW4.txt`，加上分组注释：

```bash
cat > Config/CMIOT-AX18-NOWIFI-FW4.txt <<'OVERLAY_EOF'
# --- 防火墙栈切换（FW4 nftables）---
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_firewall=n
... (从 diff 结果填入实际内容)

# --- 代理插件状态切换 ---
... (从 diff 结果填入实际内容)

# --- 其他差异 ---
... (从 diff 结果填入实际内容)
OVERLAY_EOF
```

- [ ] **步骤 5：验证新方式导出结果与旧方式一致**

```bash
bash Scripts/export_config.sh \
    --device CMIOT-AX18-NOWIFI --fw fw3 \
    --output /tmp/cmiot-new-fw3.txt

bash Scripts/export_config.sh \
    --device CMIOT-AX18-NOWIFI --fw fw4 \
    --output /tmp/cmiot-new-fw4.txt

# 对比（忽略注释和空行）
diff <(grep -v '^#' /tmp/cmiot-old-fw3.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/cmiot-new-fw3.txt | grep -v '^\s*$')

diff <(grep -v '^#' /tmp/cmiot-old-fw4.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/cmiot-new-fw4.txt | grep -v '^\s*$')
```

预期：两组 diff 均无输出（完全一致）

- [ ] **步骤 6：Commit**

```bash
git add Config/CMIOT-AX18-NOWIFI.txt Config/CMIOT-AX18-NOWIFI-FW4.txt
git commit -m "refactor(配置): CMIOT-AX18-NOWIFI 迁移到 FW4 overlay 模式"
```

---

### 任务 4：迁移 JD-AX1800PRO-WIFI

**文件：**
- 重命名：`Config/JD-AX1800PRO-WIFI-FW3.txt` → `Config/JD-AX1800PRO-WIFI.txt`
- 重写：`Config/JD-AX1800PRO-WIFI-FW4.txt`

- [ ] **步骤 1：导出旧结果作为基准**

```bash
bash Scripts/export_config.sh \
    --device JD-AX1800PRO-WIFI --fw fw3 \
    --output /tmp/jd1800pro-old-fw3.txt

bash Scripts/export_config.sh \
    --device JD-AX1800PRO-WIFI --fw fw4 \
    --output /tmp/jd1800pro-old-fw4.txt
```

- [ ] **步骤 2：重命名 FW3 文件**

```bash
git mv Config/JD-AX1800PRO-WIFI-FW3.txt Config/JD-AX1800PRO-WIFI.txt
```

- [ ] **步骤 3：生成 FW4 覆盖文件**

```bash
diff Config/JD-AX1800PRO-WIFI.txt Config/JD-AX1800PRO-WIFI-FW4.txt | \
    grep '^>' | sed 's/^> //' | \
    grep -E '^CONFIG_|^# ' > /tmp/jd1800pro-fw4-diff.txt

cat /tmp/jd1800pro-fw4-diff.txt
```

- [ ] **步骤 4：审查差异后重写 FW4 文件**

将 diff 结果写入 `Config/JD-AX1800PRO-WIFI-FW4.txt`，加上分组注释。

- [ ] **步骤 5：验证一致性**

```bash
bash Scripts/export_config.sh \
    --device JD-AX1800PRO-WIFI --fw fw3 \
    --output /tmp/jd1800pro-new-fw3.txt

bash Scripts/export_config.sh \
    --device JD-AX1800PRO-WIFI --fw fw4 \
    --output /tmp/jd1800pro-new-fw4.txt

diff <(grep -v '^#' /tmp/jd1800pro-old-fw3.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/jd1800pro-new-fw3.txt | grep -v '^\s*$')

diff <(grep -v '^#' /tmp/jd1800pro-old-fw4.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/jd1800pro-new-fw4.txt | grep -v '^\s*$')
```

- [ ] **步骤 6：Commit**

```bash
git add Config/JD-AX1800PRO-WIFI.txt Config/JD-AX1800PRO-WIFI-FW4.txt
git commit -m "refactor(配置): JD-AX1800PRO-WIFI 迁移到 FW4 overlay 模式"
```

---

### 任务 5：迁移 JD-AX1800PRO-NOWIFI

**文件：**
- 重命名：`Config/JD-AX1800PRO-NOWIFI-FW3.txt` → `Config/JD-AX1800PRO-NOWIFI.txt`
- 重写：`Config/JD-AX1800PRO-NOWIFI-FW4.txt`

- [ ] **步骤 1：导出旧结果作为基准**

```bash
bash Scripts/export_config.sh \
    --device JD-AX1800PRO-NOWIFI --fw fw3 \
    --output /tmp/jd1800pro-nowifi-old-fw3.txt

bash Scripts/export_config.sh \
    --device JD-AX1800PRO-NOWIFI --fw fw4 \
    --output /tmp/jd1800pro-nowifi-old-fw4.txt
```

- [ ] **步骤 2：重命名 FW3 文件**

```bash
git mv Config/JD-AX1800PRO-NOWIFI-FW3.txt Config/JD-AX1800PRO-NOWIFI.txt
```

- [ ] **步骤 3：生成 FW4 覆盖文件**

```bash
diff Config/JD-AX1800PRO-NOWIFI.txt Config/JD-AX1800PRO-NOWIFI-FW4.txt | \
    grep '^>' | sed 's/^> //' | \
    grep -E '^CONFIG_|^# ' > /tmp/jd1800pro-nowifi-fw4-diff.txt

cat /tmp/jd1800pro-nowifi-fw4-diff.txt
```

- [ ] **步骤 4：审查差异后重写 FW4 文件**

- [ ] **步骤 5：验证一致性**

```bash
bash Scripts/export_config.sh \
    --device JD-AX1800PRO-NOWIFI --fw fw3 \
    --output /tmp/jd1800pro-nowifi-new-fw3.txt

bash Scripts/export_config.sh \
    --device JD-AX1800PRO-NOWIFI --fw fw4 \
    --output /tmp/jd1800pro-nowifi-new-fw4.txt

diff <(grep -v '^#' /tmp/jd1800pro-nowifi-old-fw3.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/jd1800pro-nowifi-new-fw3.txt | grep -v '^\s*$')

diff <(grep -v '^#' /tmp/jd1800pro-nowifi-old-fw4.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/jd1800pro-nowifi-new-fw4.txt | grep -v '^\s*$')
```

- [ ] **步骤 6：Commit**

```bash
git add Config/JD-AX1800PRO-NOWIFI.txt Config/JD-AX1800PRO-NOWIFI-FW4.txt
git commit -m "refactor(配置): JD-AX1800PRO-NOWIFI 迁移到 FW4 overlay 模式"
```

---

### 任务 6：迁移 JD-AX6600-WIFI

**文件：**
- 重命名：`Config/JD-AX6600-WIFI-FW3.txt` → `Config/JD-AX6600-WIFI.txt`
- 重写：`Config/JD-AX6600-WIFI-FW4.txt`

- [ ] **步骤 1：导出旧结果作为基准**

```bash
bash Scripts/export_config.sh \
    --device JD-AX6600-WIFI --fw fw3 \
    --output /tmp/jd6600-old-fw3.txt

bash Scripts/export_config.sh \
    --device JD-AX6600-WIFI --fw fw4 \
    --output /tmp/jd6600-old-fw4.txt
```

- [ ] **步骤 2：重命名 FW3 文件**

```bash
git mv Config/JD-AX6600-WIFI-FW3.txt Config/JD-AX6600-WIFI.txt
```

- [ ] **步骤 3：生成 FW4 覆盖文件**

```bash
diff Config/JD-AX6600-WIFI.txt Config/JD-AX6600-WIFI-FW4.txt | \
    grep '^>' | sed 's/^> //' | \
    grep -E '^CONFIG_|^# ' > /tmp/jd6600-fw4-diff.txt

cat /tmp/jd6600-fw4-diff.txt
```

- [ ] **步骤 4：审查差异后重写 FW4 文件**

- [ ] **步骤 5：验证一致性**

```bash
bash Scripts/export_config.sh \
    --device JD-AX6600-WIFI --fw fw3 \
    --output /tmp/jd6600-new-fw3.txt

bash Scripts/export_config.sh \
    --device JD-AX6600-WIFI --fw fw4 \
    --output /tmp/jd6600-new-fw4.txt

diff <(grep -v '^#' /tmp/jd6600-old-fw3.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/jd6600-new-fw3.txt | grep -v '^\s*$')

diff <(grep -v '^#' /tmp/jd6600-old-fw4.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/jd6600-new-fw4.txt | grep -v '^\s*$')
```

- [ ] **步骤 6：Commit**

```bash
git add Config/JD-AX6600-WIFI.txt Config/JD-AX6600-WIFI-FW4.txt
git commit -m "refactor(配置): JD-AX6600-WIFI 迁移到 FW4 overlay 模式"
```

---

### 任务 7：迁移 MIR3G-WIFI-MINI 和 GL-MT6000（无 FW4 对应）

**文件：**
- 重命名：`Config/MIR3G-WIFI-MINI-FW3.txt` → `Config/MIR3G-WIFI-MINI.txt`
- 重命名：`Config/GL-MT6000-WIFI-FW3.txt` → `Config/GL-MT6000-WIFI.txt`

- [ ] **步骤 1：重命名（无 FW4 overlay，直接改名）**

```bash
git mv Config/MIR3G-WIFI-MINI-FW3.txt Config/MIR3G-WIFI-MINI.txt
git mv Config/GL-MT6000-WIFI-FW3.txt Config/GL-MT6000-WIFI.txt
```

- [ ] **步骤 2：验证导出正常**

```bash
bash Scripts/export_config.sh \
    --device MIR3G-WIFI-MINI --fw fw3 \
    --output /tmp/mir3g-new-fw3.txt

bash Scripts/export_config.sh \
    --device GL-MT6000-WIFI --fw fw3 \
    --output /tmp/gl-mt6000-new-fw3.txt
```

预期：均正常导出，无报错

- [ ] **步骤 3：Commit**

```bash
git add Config/MIR3G-WIFI-MINI.txt Config/GL-MT6000-WIFI.txt
git commit -m "refactor(配置): MIR3G-MINI 和 GL-MT6000 去掉 -FW3 后缀"
```

---

### 任务 8：更新现有测试并运行全量验证

**文件：**
- 修改：`Scripts/tests/test_export_config.sh`
- 修改：`Scripts/tests/test_export_config_prefers_direct_fw4_file.sh`

- [ ] **步骤 1：检查现有测试是否需要调整**

现有测试 `test_export_config.sh` 使用 `DEVICE-A-FW3.txt` 和 `DEVICE-A-FW4.txt`。新逻辑中 `resolve_device_config()` 优先找 `{device}.txt`，所以需要确认测试中的文件名是否需要调整。

检查 `test_export_config.sh`：
- 测试使用 `DEVICE-A-FW3.txt`，新逻辑会 fallback 到 `-FW3.txt`（兼容期），所以**无需改动**
- 但 `DEVICE-A-FW4.txt` 在旧逻辑中被 `resolve_device_config` 直接选中，新逻辑中 FW4 文件不再作为基线查找目标，需要确认测试意图

检查 `test_export_config_prefers_direct_fw4_file.sh`：
- 测试验证 `DEVICE-A-FW4.txt` 优先于 `DEVICE-A-FW3.txt`
- 新逻辑中 FW4 文件不再是独立基线，此测试**需要重写**为验证 overlay 机制

- [ ] **步骤 2：重写 test_export_config_prefers_direct_fw4_file.sh**

```bash
#!/bin/bash

# 说明：验证 --fw fw4 时，FW4 overlay 文件的内容能正确覆盖基线配置。

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
EXPORT_SCRIPT="$SCRIPT_DIR/export_config.sh"

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/device-overlays"

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_GENERAL_MARKER=y
EOF

cat > "$TMPDIR/DEVICE-A.txt" <<'EOF'
CONFIG_FROM_BASE=y
CONFIG_STACK=fw3
EOF

cat > "$TMPDIR/DEVICE-A-FW4.txt" <<'EOF'
CONFIG_FROM_FW4_OVERLAY=y
CONFIG_STACK=fw4
EOF

OUT_FILE="$TMPDIR/fw4.txt"

bash "$EXPORT_SCRIPT" \
    --config-dir "$TMPDIR" \
    --device "DEVICE-A" \
    --fw "fw4" \
    --output "$OUT_FILE" >/dev/null

grep -q '^CONFIG_GENERAL_MARKER=y$' "$OUT_FILE"
grep -q '^CONFIG_FROM_BASE=y$' "$OUT_FILE"
grep -q '^CONFIG_FROM_FW4_OVERLAY=y$' "$OUT_FILE"
grep -n '^CONFIG_STACK=' "$OUT_FILE" | tail -n 1 | grep -q 'CONFIG_STACK=fw4'

echo "test_export_config_prefers_direct_fw4_file: ok"
```

- [ ] **步骤 3：运行全量测试**

```bash
# 运行所有相关测试
bash Scripts/tests/test_export_config.sh
bash Scripts/tests/test_export_config_fw4_overlay.sh
bash Scripts/tests/test_export_config_prefers_direct_fw4_file.sh
bash Scripts/tests/test_export_config_parameterized.sh
bash Scripts/tests/test_split_device_fw4_exports.sh
```

预期：全部 PASS

- [ ] **步骤 4：Commit**

```bash
git add Scripts/tests/test_export_config_prefers_direct_fw4_file.sh
git commit -m "test(配置导出): 重写 FW4 文件优先级测试为 overlay 覆盖测试"
```

---

### 任务 9：最终全量验证

- [ ] **步骤 1：运行所有 export 相关测试**

```bash
for test in Scripts/tests/test_export_config*.sh Scripts/tests/test_split_device_fw4_exports.sh; do
    echo "--- Running $test ---"
    bash "$test"
done
```

预期：全部 PASS

- [ ] **步骤 2：验证所有设备 FW4 导出结果与旧方式一致**

```bash
for device in CMIOT-AX18-NOWIFI JD-AX1800PRO-WIFI JD-AX1800PRO-NOWIFI JD-AX6600-WIFI; do
    echo "--- $device ---"
    bash Scripts/export_config.sh --device "$device" --fw fw4 --output "/tmp/final-${device}-fw4.txt"
    grep -n '^CONFIG_PACKAGE_firewall4=' "/tmp/final-${device}-fw4.txt" | tail -n 1
    grep -n '^CONFIG_PACKAGE_firewall=' "/tmp/final-${device}-fw4.txt" | tail -n 1
done
```

预期：所有设备的 firewall4=y、firewall=n

- [ ] **步骤 3：检查文件结构符合预期**

```bash
ls Config/*.txt | sort
```

预期输出：
```
Config/GENERAL.txt
Config/JD-AX1800PRO-NOWIFI.txt
Config/JD-AX1800PRO-NOWIFI-FW4.txt
Config/JD-AX1800PRO-WIFI.txt
Config/JD-AX1800PRO-WIFI-FW4.txt
Config/JD-AX6600-WIFI.txt
Config/JD-AX6600-WIFI-FW4.txt
Config/CMIOT-AX18-NOWIFI.txt
Config/CMIOT-AX18-NOWIFI-FW4.txt
Config/MIR3G-WIFI-MINI.txt
Config/GL-MT6000-WIFI.txt
Config/x86.txt
```
