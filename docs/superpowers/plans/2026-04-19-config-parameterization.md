# 配置参数化重构实现计划

> **给执行型 agent 的要求：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐项执行。所有步骤都使用 `- [ ]` 复选框格式追踪。

**目标：** 将现有 `设备-FW3/FW4.txt` 组合文件重构为“基础层 + 防火墙层 + 设备层 + overlay 层”的参数化配置体系，并让脚本与 workflow 通过参数生成最终配置。

**架构：** 保留 `GENERAL.txt`、`GENERAL-SERVICE.txt` 与 `GENERAL-FW3/FW4.txt` 作为稳定基础层；把设备差异迁移到 `Config/devices/`；把“同一设备在不同 fw 下的差异”迁移到 `Config/device-overlays/`；把 `FRPS`、`APK`、`IPK` 等用户可选差异迁移到 `Config/overlays/`；最后重写导出脚本和 workflow 输入，使之改为 `device/fw/overlays` 参数驱动。

**技术栈：** Bash、GitHub Actions YAML、纯文本配置文件、现有 shell 测试脚本

---

### 任务 1：为参数化配置组合补测试

**文件：**
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/test_export_config_parameterized.sh`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/export_config.sh`

- [ ] **步骤 1：先写失败测试，定义新的参数接口**

```bash
bash "$EXPORT_SCRIPT" \
  --config-dir "$TMPDIR" \
  --device "DEVICE-A" \
  --fw "fw3" \
  --overlay "frps,apk" \
  --output "$OUT"

grep -q '^CONFIG_COMMON=y$' "$OUT"
grep -q '^CONFIG_SERVICE=y$' "$OUT"
grep -q '^CONFIG_FW=fw3$' "$OUT"
grep -q '^CONFIG_DEVICE=device-a$' "$OUT"
grep -n '^CONFIG_FRP_ROLE=' "$OUT" | tail -n 1 | grep -q 'server'
grep -n '^CONFIG_PKG_FORMAT=' "$OUT" | tail -n 1 | grep -q 'apk'
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`bash Scripts/test_export_config_parameterized.sh`

预期：失败，因为 `export_config.sh` 还不支持 `--device/--fw/--overlay` 接口。

- [ ] **步骤 3：补最小实现，支持参数驱动**

```bash
general_configs="GENERAL.txt GENERAL-SERVICE.txt"
fw_config="GENERAL-${fw^^}.txt"
device_config="devices/${device}.txt"
```

- [ ] **步骤 4：运行测试并确认通过**

运行：`bash Scripts/test_export_config_parameterized.sh`

预期：输出 `ok`

- [ ] **步骤 5：提交**

```bash
git add Scripts/export_config.sh Scripts/test_export_config_parameterized.sh
git commit -m "test: add parameterized config export"
```

### 任务 2：新增 overlay 解析与互斥校验

**文件：**
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/export_config.sh`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/test_config_overlay_conflicts.sh`

- [ ] **步骤 1：先写 overlay 冲突测试**

```bash
if bash "$EXPORT_SCRIPT" \
  --config-dir "$TMPDIR" \
  --device "DEVICE-A" \
  --fw "fw3" \
  --overlay "apk,ipk" \
  --output "$OUT"; then
  echo "apk/ipk should conflict" >&2
  exit 1
fi
```

- [ ] **步骤 2：运行测试并确认失败**

运行：`bash Scripts/test_config_overlay_conflicts.sh`

预期：失败，因为当前脚本还未做 `apk/ipk` 互斥校验。

- [ ] **步骤 3：补最小实现**

```bash
case ",${overlay_list}," in
  *,apk,*,ipk,*|*,ipk,*,apk,*)
    echo "overlay apk 与 ipk 不能同时启用" >&2
    exit 1
    ;;
esac
```

- [ ] **步骤 4：运行测试并确认通过**

运行：`bash Scripts/test_config_overlay_conflicts.sh`

预期：输出 `ok`

- [ ] **步骤 5：提交**

```bash
git add Scripts/export_config.sh Scripts/test_config_overlay_conflicts.sh
git commit -m "test: enforce overlay conflicts"
```

### 任务 3：迁移设备配置到 `Config/devices/`

**文件：**
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/devices/IPQ60XX-NOWIFI.txt`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/devices/GL-MT6000-WIFI.txt`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/device-overlays/IPQ60XX-NOWIFI-FW3.txt`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/device-overlays/IPQ60XX-NOWIFI-FW4.txt`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/device-overlays/GL-MT6000-WIFI-FW3.txt`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/device-overlays/GL-MT6000-WIFI-FW4.txt`
- 删除：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/IPQ60XX-NOWIFI-FW3.txt`
- 删除：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/IPQ60XX-NOWIFI-FW4.txt`
- 删除：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/GL-MT6000-WIFI-FW3.txt`
- 删除：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/GL-MT6000-WIFI-FW4.txt`
- 删除或延后迁移：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/IPQ60XX-NOWIFI_lite-FW3.txt`

- [ ] **步骤 1：先生成迁移清单**

```text
IPQ60XX-NOWIFI:
- 保留目标平台、设备列表、无线驱动开关
- 保留设备特有页面或包
- 移除基础层同值项

GL-MT6000-WIFI:
- 保留目标平台、设备差异项
- 移除基础层同值项
```

- [ ] **步骤 2：写入两个设备文件**

```text
Config/devices/IPQ60XX-NOWIFI.txt
Config/devices/GL-MT6000-WIFI.txt
```

- [ ] **步骤 3：运行去重检测并确认设备层没有基础层同值项**

运行：`bash Scripts/test_device_config_dedup.sh`

预期：输出 `ok`

- [ ] **步骤 4：删除旧设备-FW 文件**

使用 `apply_patch` 删除旧文件。

- [ ] **步骤 5：提交**

```bash
git add Config/devices
git rm Config/IPQ60XX-NOWIFI-FW3.txt Config/IPQ60XX-NOWIFI-FW4.txt Config/GL-MT6000-WIFI-FW3.txt Config/GL-MT6000-WIFI-FW4.txt
git commit -m "refactor: move device configs into layered files"
```

### 任务 4：迁移 overlay 到 `Config/overlays/`

**文件：**
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/overlays/FRPS.txt`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/overlays/APK.txt`
- 新建：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/overlays/IPK.txt`
- 评估迁移：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Config/IPQ60XX-NOWIFI-FW3-FRPS-override.txt`

- [ ] **步骤 1：先定义 overlay 内容来源**

```text
FRPS:
- frpc/frps 角色切换

APK:
- 包管理器切换到 apk

IPK:
- 包管理器显式切回 ipk
```

- [ ] **步骤 2：写入 overlay 文件**

```text
Config/overlays/FRPS.txt
Config/overlays/APK.txt
Config/overlays/IPK.txt
```

- [ ] **步骤 3：运行参数化导出测试验证 overlay 顺序**

运行：`bash Scripts/test_export_config_parameterized.sh`

预期：后置 overlay 能覆盖前值。

- [ ] **步骤 4：删除旧 overlay 文件或迁移为新路径**

使用 `apply_patch` 删除或替换旧 `IPQ60XX-NOWIFI-FW3-FRPS-override.txt`。

- [ ] **步骤 5：提交**

```bash
git add Config/overlays
git commit -m "refactor: move optional config deltas into overlays"
```

### 任务 5：让脚本自动叠加设备栈差异层

**文件：**
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/export_config.sh`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/test_export_config_parameterized.sh`

- [ ] **步骤 1：在脚本里自动查找 `device-overlays/<device>-<FW>.txt`**

```bash
device_overlay_config="device-overlays/${device}-${fw^^}.txt"
if [ -f "$config_dir/$device_overlay_config" ]; then
  cat "$config_dir/$device_overlay_config" >> "$output_config"
fi
```

- [ ] **步骤 2：运行参数化导出测试确认自动叠加生效**

运行：`bash Scripts/test_export_config_parameterized.sh`

- [ ] **步骤 3：提交**

```bash
git add Scripts/export_config.sh Scripts/test_export_config_parameterized.sh
git commit -m "refactor: auto-apply device fw overlays"
```

### 任务 6：重构 workflow 为参数驱动

**文件：**
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/DEFAULT.yml`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CUSTOM.yml`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CORE-ALL.yml`
- 可选修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/main.yml`

- [ ] **步骤 1：先把 workflow 输入改成参数**

```yaml
WRT_DEVICE:
WRT_FIREWALL:
WRT_OVERLAYS:
```

- [ ] **步骤 2：移除旧 `WRT_CONFIG=设备-FW*.txt` 驱动方式**

把最终 `.config` 生成步骤改成：

```bash
bash "$GITHUB_WORKSPACE/Scripts/export_config.sh" \
  --config-dir "$GITHUB_WORKSPACE/Config" \
  --device "$WRT_DEVICE" \
  --fw "$WRT_FIREWALL" \
  --overlay "$WRT_OVERLAYS" \
  --output ".config"
```

- [ ] **步骤 3：运行配置解析测试**

运行：

```bash
bash Scripts/test_export_config_parameterized.sh
bash Scripts/test_config_overlay_conflicts.sh
```

- [ ] **步骤 4：提交**

```bash
git add .github/workflows
git commit -m "ci: switch config assembly to parameterized inputs"
```

### 任务 7：更新 README 与测试说明

**文件：**
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/README.md`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/docs/superpowers/specs/2026-04-19-config-parameterization-design.md`
- 修改：`/Users/lin/Documents/Git/Linjw/LjwOpenWrt/docs/superpowers/plans/2026-04-19-config-parameterization.md`

- [ ] **步骤 1：把 README 示例改成参数驱动**

```text
WRT_DEVICE=IPQ60XX-NOWIFI
WRT_FIREWALL=fw3
WRT_OVERLAYS=frps,apk
```

- [ ] **步骤 2：删掉旧 `设备-FW3/FW4.txt` 示例**

README 中不再出现旧配置文件名作为主入口。

- [ ] **步骤 3：提交**

```bash
git add README.md docs/superpowers/specs/2026-04-19-config-parameterization-design.md docs/superpowers/plans/2026-04-19-config-parameterization.md
git commit -m "docs: document parameterized config layering"
```

### 任务 8：跑最终回归

**文件：**
- 不新增文件

- [ ] **步骤 1：运行核心测试**

```bash
bash Scripts/test_export_config_parameterized.sh
bash Scripts/test_config_overlay_conflicts.sh
bash Scripts/test_device_config_dedup.sh
bash Scripts/test_resolve_general_configs.sh
```

- [ ] **步骤 2：检查导出结果与工作区状态**

```bash
git diff --check
git status --short
```

- [ ] **步骤 3：提交最终收口**

```bash
git add Config Scripts .github/workflows README.md
git commit -m "refactor: parameterize layered config assembly"
```

## 自检结果

- 规格覆盖：目录结构、脚本接口、overlay 冲突、workflow 参数化、README 迁移均已映射到任务。
- 文案检查：计划中没有待补说明或延后实现字样。
- 命名一致性：统一使用 `device/fw/overlays`、`Config/devices/`、`Config/overlays/`。
