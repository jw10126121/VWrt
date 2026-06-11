# GENERAL 配置分层实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 将共享配置拆分为 `GENERAL.txt` 与 `GENERAL-FW3.txt` 两层，并让 workflow 支持按顺序合并多个基础配置文件后再拼接机型配置。

**架构：** 保留现有 `WRT_GENERAL_CONFIG` 输入名不变，仅扩展为支持空格分隔的多文件列表。配置组装顺序固定为“基础层从左到右 + 机型配置最后覆盖”，这样既兼容现有单文件调用，又能支持后续继续拆层。

**技术栈：** OpenWrt `.config`、GitHub Actions YAML、POSIX shell 测试脚本

---

### 任务 1：增加多基础配置合并顺序测试

**文件：**
- 新建：`Scripts/test_merge_general_configs.sh`

- [ ] **步骤 1：先写失败测试脚本**

```bash
#!/bin/bash

set -eu

TMPDIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMPDIR"
}
trap cleanup EXIT

cat > "$TMPDIR/GENERAL.txt" <<'EOF'
CONFIG_ALPHA=y
CONFIG_SHARED=general
EOF

cat > "$TMPDIR/GENERAL-FW3.txt" <<'EOF'
CONFIG_SHARED=fw3
CONFIG_FW3_ONLY=y
EOF

cat > "$TMPDIR/DEVICE.txt" <<'EOF'
CONFIG_SHARED=device
CONFIG_DEVICE_ONLY=y
EOF

ACTUAL="$TMPDIR/actual.config"

for cfg in GENERAL.txt GENERAL-FW3.txt; do
	cat "$TMPDIR/$cfg" >> "$ACTUAL"
done
cat "$TMPDIR/DEVICE.txt" >> "$ACTUAL"

grep -q '^CONFIG_ALPHA=y$' "$ACTUAL"
grep -q '^CONFIG_FW3_ONLY=y$' "$ACTUAL"
grep -q '^CONFIG_DEVICE_ONLY=y$' "$ACTUAL"
tail -n 1 "$ACTUAL" | grep -q '^CONFIG_DEVICE_ONLY=y$'
grep -n '^CONFIG_SHARED=' "$ACTUAL" | tail -n 1 | grep -q 'CONFIG_SHARED=device'

echo "test_merge_general_configs: ok"
```

- [ ] **步骤 2：运行测试确认当前验证逻辑成立**

运行：`rtk bash Scripts/test_merge_general_configs.sh`

预期：输出 `test_merge_general_configs: ok`

### 任务 2：收敛 GENERAL 基础层并新增 FW3 共享层

**文件：**
- 修改：`Config/GENERAL.txt`
- 新建：`Config/GENERAL-FW3.txt`

- [ ] **步骤 1：精简 `Config/GENERAL.txt`**

保留：

```text
CONFIG_DEVEL=y
CONFIG_CCACHE=y
CONFIG_TARGET_PER_DEVICE_ROOTFS=y
CONFIG_TARGET_ROOTFS_EXT4FS=n
CONFIG_IB=y
CONFIG_IB_STANDALONE=y
CONFIG_PACKAGE_kmod-fs-btrfs=y
CONFIG_PACKAGE_kmod-fuse=y
CONFIG_PACKAGE_kmod-dsa=y
CONFIG_PACKAGE_kmod-dsa-tag-dsa=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_kmod-wireguard=y
CONFIG_PACKAGE_kmod-inet-diag=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_blockd=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_gdisk=y
CONFIG_PACKAGE_dmesg=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_mmc-utils=y
CONFIG_PACKAGE_nand-utils=y
CONFIG_PACKAGE_openssh-keygen=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_openssl-util=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_ca-certificates=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_dnsmasq_full_dhcp=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_dnsmasq_full_ipset=y
CONFIG_PACKAGE_ppp=y
CONFIG_PACKAGE_ppp-mod-pppoe=y
CONFIG_PACKAGE_uhttpd-mod-ubus=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-lib-base=y
CONFIG_PACKAGE_luci-lua-runtime=y
CONFIG_PACKAGE_luci-lib-json=y
CONFIG_PACKAGE_luci-mod-rpc=y
CONFIG_PACKAGE_luci-lib-fs=y
CONFIG_PACKAGE_luci-proto-ppp=y
```

- [ ] **步骤 2：新增 `Config/GENERAL-FW3.txt`**

写入当前多机型高度复用的 FW3 共享层，例如：

```text
CONFIG_PACKAGE_firewall4=n
CONFIG_PACKAGE_firewall=y
CONFIG_PACKAGE_iptables=y
CONFIG_PACKAGE_ip6tables=y
CONFIG_PACKAGE_ip6tables-extra=y
CONFIG_PACKAGE_ip6tables-mod-nat=y
CONFIG_PACKAGE_kmod-ipt-fullconenat=y
CONFIG_PACKAGE_iptables-mod-fullconenat=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-homeproxy=n
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
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn=y
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

- [ ] **步骤 3：保留机型覆盖空间**

确认轻量版或 FRPS 专用版保留自身覆盖项，不强行删掉：

```text
Config/IPQ60XX-NOWIFI_lite.txt
Config/IPQ60XX-NOWIFI-FW3-FRPS-override.txt
```

### 任务 3：修改 workflow 支持多基础配置文件

**文件：**
- 修改：`.github/workflows/main.yml`
- 修改：`.github/workflows/DEFAULT.yml`
- 修改：`.github/workflows/CUSTOM.yml`
- 修改：`.github/workflows/CORE-ALL.yml`

- [ ] **步骤 1：更新输入说明与默认值**

将说明统一为“支持空格分隔多个配置文件”，并把默认值改为：

```yaml
GENERAL.txt GENERAL-FW3.txt
```

- [ ] **步骤 2：修改 `.config` 合并逻辑**

把当前单次 `cat`：

```bash
cat $GITHUB_WORKSPACE/$WRT_DIR_CONFIGS/$WRT_GENERAL_CONFIG $GITHUB_WORKSPACE/$WRT_DIR_CONFIGS/$WRT_CONFIG >> .config
```

改为循环拼接：

```bash
for general_cfg in $WRT_GENERAL_CONFIG; do
  cat "$GITHUB_WORKSPACE/$WRT_DIR_CONFIGS/$general_cfg" >> .config
done
cat "$GITHUB_WORKSPACE/$WRT_DIR_CONFIGS/$WRT_CONFIG" >> .config
```

- [ ] **步骤 3：检查所有入口一致性**

确认下面文件的默认值、说明和合并方式一致：

```text
.github/workflows/main.yml
.github/workflows/DEFAULT.yml
.github/workflows/CUSTOM.yml
.github/workflows/CORE-ALL.yml
```

### 任务 4：验证配置与 workflow 改动

**文件：**
- 测试：`Scripts/test_merge_general_configs.sh`

- [ ] **步骤 1：运行新增合并测试**

运行：`rtk bash Scripts/test_merge_general_configs.sh`

预期：输出 `test_merge_general_configs: ok`

- [ ] **步骤 2：运行现有相关测试**

运行：`rtk bash Scripts/test_diy_config_structure.sh`

预期：输出 `test_diy_config_structure: ok`

- [ ] **步骤 3：做基础语法检查**

运行：

```bash
rtk bash -n Scripts/test_merge_general_configs.sh
rtk rg -n "GENERAL.txt GENERAL-FW3.txt|for general_cfg in \\$WRT_GENERAL_CONFIG" .github/workflows -S
```

预期：

- shell 语法检查无输出且退出码为 0
- workflow 中能查到新的默认值和循环拼接逻辑
