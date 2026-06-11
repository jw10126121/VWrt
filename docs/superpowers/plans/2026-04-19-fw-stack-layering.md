# FW3/FW4/共享服务分层实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 将当前 `GENERAL-FW3.txt` 拆分为“共享服务层 + 纯 FW3 栈”，新增 `GENERAL-FW4.txt`，并让 workflow 根据配置类型自动选择合适的基础配置组合。

**架构：** 保留 `GENERAL.txt` 作为全局基础层，新增 `GENERAL-SERVICE.txt` 存放不强绑定 FW3/FW4 的共享服务项；`GENERAL-FW3.txt` 和 `GENERAL-FW4.txt` 分别只承载对应防火墙栈与明确绑定该栈的默认代理策略。workflow 允许手动传入 `WRT_GENERAL_CONFIG`，若留空则根据 `WRT_CONFIG` 是否为 `-V` 自动选择。

**技术栈：** OpenWrt `.config`、GitHub Actions YAML、POSIX shell 测试脚本

---

### 任务 1：增加基础配置自动选择测试

**文件：**
- 新建：`Scripts/test_resolve_general_configs.sh`

- [ ] **步骤 1：先写失败测试脚本**

```bash
#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RESOLVE_SCRIPT="$SCRIPT_DIR/resolve_general_configs.sh"

FW3_RESULT=$(bash "$RESOLVE_SCRIPT" "" "IPQ60XX-NOWIFI-FW3.txt")
[ "$FW3_RESULT" = "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt" ]

FW4_RESULT=$(bash "$RESOLVE_SCRIPT" "" "IPQ60XX-NOWIFI-FW4.txt")
[ "$FW4_RESULT" = "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW4.txt" ]

MANUAL_RESULT=$(bash "$RESOLVE_SCRIPT" "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt" "IPQ60XX-NOWIFI-FW4.txt")
[ "$MANUAL_RESULT" = "GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt" ]

echo "test_resolve_general_configs: ok"
```

- [ ] **步骤 2：运行测试确认当前存在缺口**

运行：`rtk bash Scripts/test_resolve_general_configs.sh`

预期：因 `resolve_general_configs.sh` 尚不存在而失败

### 任务 2：拆分共享服务层与 FW3/FW4 栈层

**文件：**
- 新建：`Config/GENERAL-SERVICE.txt`
- 修改：`Config/GENERAL-FW3.txt`
- 新建：`Config/GENERAL-FW4.txt`

- [ ] **步骤 1：新增 `Config/GENERAL-SERVICE.txt`**

放入共享服务层，例如：

```text
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-onliner=y
CONFIG_PACKAGE_luci-app-ramfree=y
CONFIG_PACKAGE_luci-i18n-ramfree-zh-cn=y
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-i18n-autoreboot-zh-cn=y
CONFIG_PACKAGE_luci-app-filetransfer=y
CONFIG_PACKAGE_luci-i18n-filetransfer-zh-cn=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_luci-i18n-sqm-zh-cn=y
CONFIG_PACKAGE_luci-app-socat=y
CONFIG_PACKAGE_luci-i18n-socat-zh-cn=y
CONFIG_PACKAGE_socat=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-i18n-upnp-zh-cn=y
CONFIG_PACKAGE_luci-app-ddns=y
CONFIG_PACKAGE_luci-i18n-ddns-zh-cn=y
CONFIG_PACKAGE_luci-app-ddns-go=m
CONFIG_PACKAGE_luci-i18n-ddns-go-zh-cn=m
CONFIG_PACKAGE_ddns-go=m
CONFIG_PACKAGE_frpc=y
CONFIG_PACKAGE_luci-app-frpc=y
CONFIG_PACKAGE_luci-i18n-frpc-zh-cn=y
CONFIG_PACKAGE_frps=m
CONFIG_PACKAGE_luci-app-frps=m
CONFIG_PACKAGE_luci-i18n-frps-zh-cn=m
CONFIG_PACKAGE_watchcat=y
CONFIG_PACKAGE_luci-app-watchcat=y
CONFIG_PACKAGE_luci-i18n-watchcat-zh-cn=y
```

- [ ] **步骤 2：收敛 `Config/GENERAL-FW3.txt`**

只保留 FW3 栈与明确绑定 FW3 的默认项，例如：

```text
CONFIG_PACKAGE_firewall4=n
CONFIG_PACKAGE_firewall=y
CONFIG_PACKAGE_iptables=y
CONFIG_PACKAGE_ip6tables=y
CONFIG_PACKAGE_ip6tables-extra=y
CONFIG_PACKAGE_ip6tables-mod-nat=y
CONFIG_PACKAGE_kmod-ipt-fullconenat=y
CONFIG_PACKAGE_iptables-mod-fullconenat=y
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-ssr-plus=m
```

- [ ] **步骤 3：新增 `Config/GENERAL-FW4.txt`**

只保留 FW4 / nftables 栈与明确绑定 FW4 的默认项，例如：

```text
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_firewall=n
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_ip6tables=n
CONFIG_PACKAGE_ip6tables-extra=n
CONFIG_PACKAGE_ip6tables-mod-nat=n
CONFIG_PACKAGE_kmod-ipt-fullconenat=n
CONFIG_PACKAGE_iptables-mod-fullconenat=n
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-nf-conntrack-netlink=y
CONFIG_PACKAGE_kmod-nf-conntrack6=y
CONFIG_PACKAGE_nftables=y
CONFIG_PACKAGE_kmod-nft-core=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-offload=y
CONFIG_PACKAGE_kmod-nft-fullcone=y
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_luci-app-openclash=m
CONFIG_PACKAGE_luci-app-ssr-plus=n
```

### 任务 3：增加自动解析脚本并接入 workflow

**文件：**
- 新建：`Scripts/resolve_general_configs.sh`
- 修改：`.github/workflows/CORE-ALL.yml`
- 修改：`.github/workflows/main.yml`
- 修改：`.github/workflows/DEFAULT.yml`
- 修改：`.github/workflows/CUSTOM.yml`

- [ ] **步骤 1：实现自动解析脚本**

脚本规则：

```text
如果 WRT_GENERAL_CONFIG 非空：原样输出
如果 WRT_CONFIG 以 -FW4.txt 结尾：输出 GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW4.txt
否则：输出 GENERAL.txt GENERAL-SERVICE.txt GENERAL-FW3.txt
```

- [ ] **步骤 2：workflow 改为“留空自动选择”**

把各入口说明改成：

```text
基础配置文件，支持空格分隔多个文件；留空时按配置类型自动选择
```

默认值改为空字符串。

- [ ] **步骤 3：在 `CORE-ALL.yml` 中解析后再合并**

在读取 `WRT_CONFIG` 类型后执行：

```bash
RESOLVED_GENERAL_CONFIG=$(bash "$GITHUB_WORKSPACE/$WRT_DIR_SCRIPTS/resolve_general_configs.sh" "$WRT_GENERAL_CONFIG" "$WRT_CONFIG")
echo "RESOLVED_GENERAL_CONFIG=$RESOLVED_GENERAL_CONFIG" >> "$GITHUB_ENV"
```

并把后续 `merge_configs.sh` 的输入改成：

```bash
"$RESOLVED_GENERAL_CONFIG"
```

### 任务 4：验证

**文件：**
- 测试：`Scripts/test_resolve_general_configs.sh`
- 测试：`Scripts/test_merge_general_configs.sh`

- [ ] **步骤 1：运行自动解析测试**

运行：`rtk bash Scripts/test_resolve_general_configs.sh`

预期：输出 `test_resolve_general_configs: ok`

- [ ] **步骤 2：运行合并测试**

运行：`rtk bash Scripts/test_merge_general_configs.sh`

预期：输出 `test_merge_general_configs: ok`

- [ ] **步骤 3：做语法与引用检查**

运行：

```bash
rtk bash -n Scripts/resolve_general_configs.sh
rtk bash -n Scripts/merge_configs.sh
rtk rg -n "GENERAL-SERVICE|GENERAL-FW4|RESOLVED_GENERAL_CONFIG" .github/workflows Scripts -S
```

预期：

- shell 语法检查无输出且退出码为 0
- workflow 与脚本引用都能查到新分层文件和自动解析变量
