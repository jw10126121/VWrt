# VWrt — OpenWrt 云编译仓库

基于 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) 源码的 OpenWrt 云编译仓库，通过 GitHub Actions 自动构建多设备、多防火墙栈的固件。

## 目录

- [固件风味](#固件风味)
- [支持设备](#支持设备)
- [CI 工作流](#ci-工作流)
- [配置组织](#配置组织)
- [Overlay 系统](#overlay-系统)
- [固件默认值](#固件默认值)
- [下载固件](#下载固件)
- [刷机说明](#刷机说明)

## 固件风味

| 风味 | 源码 | 防火墙 | 说明 |
|------|------|--------|------|
| **LWRT** | `coolsnowwolf/lede` master | fw3 | 常规版，兼容性好 |
| **VWRT** | `coolsnowwolf/lede` master | fw4 (nftables) | 新版防火墙，功能更新 |

两种风味共用同一套设备配置和构建脚本，通过 `SOURCE_TYPE` 和 `WRT_FIREWALL` 参数区分。

## 支持设备

| 设备 | 架构 | 备注 |
|------|------|------|
| `CMIOT-AX18-NOWIFI` | qualcommax-ipq60xx / aarch64 | 默认无 Wi-Fi |
| `IPQ60XX-NOWIFI` | qualcommax-ipq60xx / aarch64 | 默认无 Wi-Fi |
| `JD-AX1800PRO-WIFI` | qualcommax-ipq60xx / aarch64 | 京东云亚瑟，带 Wi-Fi |
| `JD-AX6600-WIFI` | qualcommax-ipq60xx / aarch64 | 京东云雅典娜，带 Wi-Fi |
| `GL-MT6000-WIFI` | mediatek-filogic / aarch64 | GL.iNet MT6000，带 Wi-Fi |
| `x86` | x86_64 | 通用 x86 平台 |

如需调整具体机型勾选项，修改对应配置文件中的 `CONFIG_TARGET_DEVICE_*`。

## CI 工作流

[![CUSTOM-LWRT](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM-LWRT.yml/badge.svg)](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM-LWRT.yml)
[![CUSTOM-VWRT](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM-VWRT.yml/badge.svg)](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/CUSTOM-VWRT.yml)
[![DEFAULT](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/DEFAULT.yml/badge.svg)](https://github.com/jw10126121/LjwOpenWrt/actions/workflows/DEFAULT.yml)

### 预设工作流

| 工作流 | 触发方式 | 说明 |
|--------|----------|------|
| **CUSTOM-LWRT** | 定时（每月 2、16 日 03:00 UTC）/ 手动 | 批量构建 fw3 风味的全部设备 |
| **CUSTOM-VWRT** | 定时（每月 1、15 日 03:00 UTC）/ 手动 | 批量构建 fw4 风味的全部设备 |
| **DEFAULT** | 手动触发 | 单设备自定义构建，灵活选择参数 |

### DEFAULT 工作流参数

手动运行 `DEFAULT` 时，可输入以下参数：

| 参数 | 说明 | 示例 |
|------|------|------|
| `WRT_DEVICE` | 设备型号 | `CMIOT-AX18-NOWIFI` |
| `WRT_FIREWALL` | 防火墙栈 | `fw3` / `fw4` |
| `WRT_OVERLAYS` | 差异层，逗号分隔 | `frps,apk` |
| `WRT_LUCI_BRANCH` | LuCI feed 分支 | `openwrt-23.05` |
| `WRT_DIYPackages` | 包脚本选择 | `auto`（默认）/ `Packages.sh` |
| `WRT_SOURCE_HASH_INFO` | 固定 lean 提交 | commit hash |

**参数说明：**

- `WRT_LUCI_BRANCH` 留空时使用源码默认 LuCI feed
- `WRT_DIYPackages` 默认 `auto`：优先使用 `Scripts/Packages-<设备名>.sh` 或短名脚本；填 `Packages.sh` 可强制使用通用包脚本
- overlay 文件可用 `# OVERLAY_GROUP=<组名>` 声明互斥组；同组内按 `WRT_OVERLAYS` 顺序以最后一个为准

## 配置组织

配置按以下顺序叠加（后面的覆盖前面的同名项）：

```
Config/GENERAL-<设备名>.txt    # 设备专用通用配置（若不存在则用 GENERAL.txt）
Config/<设备名>-<FW>.txt       # 设备 + 防火墙栈专属配置
Config/device-overlays/<设备名>-<FW>.txt  # 设备差异层（若存在）
Config/overlays/<overlay>.txt  # 自定义差异层（按 WRT_OVERLAYS 顺序叠加）
```

### 主维护配置文件

| 设备 | fw3 配置 | fw4 配置 |
|------|----------|----------|
| CMIOT-AX18-NOWIFI | `Config/CMIOT-AX18-NOWIFI-FW3.txt` | `Config/CMIOT-AX18-NOWIFI-FW4-VWRT.txt` |
| GL-MT6000-WIFI | `Config/GL-MT6000-WIFI-FW3.txt` | `Config/GL-MT6000-WIFI-FW4-VWRT.txt` |
| JD-AX1800PRO-WIFI | `Config/JD-AX1800PRO-WIFI-FW3.txt` | `Config/JD-AX1800PRO-WIFI-FW4-VWRT.txt` |
| JD-AX6600-WIFI | `Config/JD-AX6600-WIFI-FW3.txt` | `Config/JD-AX6600-WIFI-FW4-VWRT.txt` |

## Overlay 系统

Overlay 用于在不修改设备主配置的前提下叠加功能差异。

### 内置 Overlay

| Overlay | 说明 |
|---------|------|
| `apk` | APK 包管理器 |
| `ipk` | IPK 包管理器（默认） |
| `frpc` | FRP 内网穿透客户端 |
| `frps` | FRP 内网穿透服务端 |
| `usb` | USB 支持 |
| `nousb` | 移除 USB 支持 |
| `nowifi-ipq60xx` | IPQ60XX 设备移除 Wi-Fi |

### 自定义 Overlay

1. 在 `Config/overlays/` 下创建 `.txt` 文件，例如 `Config/overlays/MYVPN.txt`
2. 使用时在 `WRT_OVERLAYS` 中填入文件名（不含扩展名），例如 `WRT_OVERLAYS=myvpn`
3. 后面的 overlay 会覆盖前面的同名配置
4. 可通过 `# OVERLAY_GROUP=<组名>` 声明互斥组，同组只保留最后出现的 overlay

## 固件默认值

| 项目 | 默认值 |
|------|--------|
| 主题 | Argon |
| LAN IP | `192.168.0.1` |
| 用户名 | `root` |
| 密码 | 空密码 |

## 下载固件

- **发布页**：[LjwOpenWrt Releases](https://github.com/jw10126121/LjwOpenWrt/releases)
- **上游源码**：[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)

## 刷机说明

适用于当前 lean 固件：

| 刷机方式 | 固件文件 | 说明 |
|----------|----------|------|
| U-Boot 恢复 | `squashfs-recovery.bin` | 适用于 Hugo U-Boot + 原厂 CDT + 双分区 GPT |
| LuCI 在线升级 | `squashfs-sysupgrade.bin` | 在 LuCI 系统升级页面上传 |

---

> ⚠️ 本仓库仅供学习与交流使用，请自行评估刷机风险并遵守相关法律法规。
