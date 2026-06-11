# FW3/FW4 Overlay 配置管理设计

## 背景

当前每个设备维护两份完整配置文件（`-FW3.txt` 和 `-FW4.txt`），但两者 80%+ 内容相同。主要差异集中在：

1. **防火墙栈切换**：iptables（FW3）↔ nftables（FW4），约 12-14 行
2. **代理插件状态**：SSR Plus ↔ HomeProxy，AdGuard Home 启禁，约 14 行
3. **插件 y/m 切换**：autoreboot、onliner 等安装状态差异

双文件维护导致每次修改都要同步两份，容易遗漏。

## 目标

以 FW3 为基线，FW4 只保留差异行（overlay），减少维护量。

## 方案：文件级 Overlay（A1）

### 文件结构变更

**Before（当前）：**
```
Config/
├── GENERAL.txt
├── CMIOT-AX18-NOWIFI-FW3.txt      # 完整配置
├── CMIOT-AX18-NOWIFI-FW4.txt      # 完整配置（大量重复）
├── JD-AX1800PRO-WIFI-FW3.txt
├── JD-AX1800PRO-WIFI-FW4.txt
├── JD-AX1800PRO-NOWIFI-FW3.txt
├── JD-AX1800PRO-NOWIFI-FW4.txt
├── JD-AX6600-WIFI-FW3.txt
├── JD-AX6600-WIFI-FW4.txt
├── MIR3G-WIFI-MINI-FW3.txt        # 无 FW4 对应
├── GL-MT6000-WIFI-FW3.txt            # 无 FW4 对应
└── x86.txt
```

**After（目标）：**
```
Config/
├── GENERAL.txt                        # 不变
├── CMIOT-AX18-NOWIFI.txt              # 原 FW3 → 基线（去掉 -FW3 后缀）
├── CMIOT-AX18-NOWIFI-FW4.txt          # 纯覆盖（只含差异行）
├── JD-AX1800PRO-WIFI.txt              # 基线
├── JD-AX1800PRO-WIFI-FW4.txt          # 纯覆盖
├── JD-AX1800PRO-NOWIFI.txt            # 基线
├── JD-AX1800PRO-NOWIFI-FW4.txt        # 纯覆盖
├── JD-AX6600-WIFI.txt                 # 基线
├── JD-AX6600-WIFI-FW4.txt             # 纯覆盖
├── MIR3G-WIFI-MINI.txt                # 原 FW3 → 基线（无 FW4）
├── GL-MT6000-WIFI.txt                    # 原 FW3 → 基线（无 FW4）
├── x86.txt                            # 不变
└── device-overlays/                   # 不变
```

### 命名规则

| 文件 | 用途 | 说明 |
|------|------|------|
| `{device}.txt` | FW3 基线 | 完整配置，直接用于 `--fw fw3` |
| `{device}-FW4.txt` | FW4 覆盖 | 只含差异行，构建时追加到基线之后 |

### 构建流程

```
--fw fw3:
  GENERAL.txt + {device}.txt → 最终 .config

--fw fw4:
  GENERAL.txt + {device}.txt + {device}-FW4.txt → 最终 .config
```

OpenWrt `.config` 格式中，同一 key 后出现的值覆盖先前值，因此 FW4 覆盖文件中的行会自动覆盖基线中的对应行。

### FW4 覆盖文件格式

FW4 覆盖文件只包含需要覆盖的行，**不包含注释头、段落分隔符等结构性内容**：

```bash
# 示例：CMIOT-AX18-NOWIFI-FW4.txt

# --- 防火墙栈切换（FW4 nftables）---
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_firewall=n
CONFIG_PACKAGE_nftables=y
CONFIG_PACKAGE_kmod-nft-core=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-offload=y
CONFIG_PACKAGE_kmod-nft-fullcone=y
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-nf-conntrack-netlink=y
CONFIG_PACKAGE_kmod-nf-conntrack6=y
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_ip6tables=n
CONFIG_PACKAGE_ip6tables-extra=n
CONFIG_PACKAGE_ip6tables-mod-nat=n
CONFIG_PACKAGE_kmod-ipt-fullconenat=n
CONFIG_PACKAGE_iptables-mod-fullconenat=n

# --- 代理插件状态切换 ---
CONFIG_PACKAGE_luci-app-ssr-plus=n
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_luci-app-adguardhome=n
CONFIG_PACKAGE_luci-app-turboacc=n

# --- 其他差异 ---
（按实际情况列出）
```

### 脚本变更

#### 1. export_config.sh — resolve_device_config()

当前查找顺序：`{device}-{FW}.txt` → `{device}.txt` → `{device}-FW3.txt`

迁移后基线统一为 `{device}.txt`，查找顺序调整为：

```bash
resolve_device_config() {
    local config_root=$1
    local device_name=$2

    # 优先查找无后缀的基线文件
    if [ -f "$config_root/${device_name}.txt" ]; then
        printf '%s\n' "${device_name}.txt"
        return 0
    fi

    # 兼容旧文件名（过渡期）
    if [ -f "$config_root/${device_name}-FW3.txt" ]; then
        printf '%s\n' "${device_name}-FW3.txt"
        return 0
    fi

    return 1
}
```

#### 2. export_config.sh — 主流程

移除 fw 参数对设备配置查找的影响，FW4 覆盖由外层逻辑追加：

```bash
# 统一查找基线（不再区分 fw3/fw4）
device_config=$(resolve_device_config "$config_dir" "$device" || true)

# ... 合并基线 ...

# --fw fw4 时追加覆盖文件
if [ "${fw}" = "fw4" ] || [ "${fw}" = "FW4" ]; then
    fw4_overlay="${device}-FW4.txt"
    if [ -f "$config_dir/$fw4_overlay" ]; then
        cat "$config_dir/$fw4_overlay" >> "$output_config"
    fi
fi
```

#### 3. diy_after_defconfig.sh:55 — 无需改动

该行匹配的是 marker file 中的设备标识（如 `CMIOT-AX18-NOWIFI`），不是配置文件名，与本次迁移无关。

#### 4. YAML 工作流 — 无需改动

CI YAML 只传 `fw3`/`fw4` 参数值给脚本，不硬编码配置文件名。

### 迁移策略

**分批迁移，逐步验证：**

| 阶段 | 设备 | 验证方式 |
|------|------|----------|
| 1 | CMIOT-AX18-NOWIFI（当前主维护） | 对比新旧导出结果是否一致 |
| 2 | JD-AX1800PRO-WIFI / NOWIFI | 同上 |
| 3 | JD-AX6600-WIFI | 同上 |
| 4 | MIR3G-WIFI-MINI / GL-MT6000 | 只重命名，无 FW4 overlay |

**验证命令：**
```bash
# 旧方式导出
bash Scripts/export_config.sh --device CMIOT-AX18-NOWIFI --fw fw4 --output /tmp/old-fw4.txt

# 新方式导出（迁移后）
bash Scripts/export_config.sh --device CMIOT-AX18-NOWIFI --fw fw4 --output /tmp/new-fw4.txt

# 对比（忽略注释和空行）
diff <(grep -v '^#' /tmp/old-fw4.txt | grep -v '^\s*$') \
     <(grep -v '^#' /tmp/new-fw4.txt | grep -v '^\s*$')
```

## 确认结论

1. **FW4 覆盖文件中的注释**：保留，方便理解差异原因
2. **`preprocess_device_config()`**：保留，当前是 no-op 不影响，将来若需标记语法仍可使用
3. **CI YAML**：无需改动，只传参数值不硬编码文件名
4. **`diy_after_defconfig.sh`**：无需改动，匹配设备标识非文件名
