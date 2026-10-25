# VWrt — OpenWrt 云编译仓库

基于 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)（Lean 源码）、[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)（VIKINGYFY 源码）、[LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt)（LibWrt 源码）和 [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)（官方 ImmortalWrt）的 OpenWrt 云编译仓库，通过 GitHub Actions 自动构建多设备、多防火墙栈的固件。

## 目录

- [VWrt — OpenWrt 云编译仓库](#vwrt--openwrt-云编译仓库)
  - [目录](#目录)
  - [固件风味](#固件风味)
  - [支持设备](#支持设备)
  - [CI 工作流](#ci-工作流)
    - [预设工作流](#预设工作流)
    - [DEFAULT 工作流参数](#default-工作流参数)
  - [配置组织](#配置组织)
    - [主维护配置文件](#主维护配置文件)
  - [Overlay 系统](#overlay-系统)
    - [内置 Overlay](#内置-overlay)
    - [自定义 Overlay](#自定义-overlay)
  - [固件默认值](#固件默认值)
  - [下载固件](#下载固件)
  - [刷机说明](#刷机说明)
  - [致谢](#致谢)

## 固件风味

| 风味（产物标记） | 源码 | 分支 | 防火墙 | 说明 |
|------|------|------|--------|------|
| **`lean`**（LWRT） | [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) | `master` | fw3 | Lean 源码，兼容性好 |
| **`vikingyfy`**（入口 `vikingyfy`） | [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) | `main` | fw4 (nftables) | VIKINGYFY 源码，用于高通设备 |
| **`libwrt`**（LIBWRT） | [LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt) | `25.12-nss` | fw4 (nftables) | LibWrt 源码，用于高通设备 |
| **`immortalwrt`** | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) | `master` | fw4 (nftables) | 官方 ImmortalWrt，非 IPQ 设备自动使用 |

**源码选择机制：** `SOURCE_TYPE` 选择构建入口，未显式传入 `WRT_REPO_URL` 时实际源码仓库按设备架构决定。`lean` 始终使用 coolsnowwolf/lede；`vikingyfy` 和 `libwrt` 在高通（IPQ）设备上分别使用 VIKINGYFY 的 immortalwrt 和 `LiBwrt/LibWrt`，在 GL-MT6000 等非 IPQ 设备上统一回退到官方 `immortalwrt/immortalwrt` 的 `master` 分支。显式传入 `WRT_REPO_URL` 时以传入仓库为准。

**风味命名：** 元信息中的“源码风味”、产物文件名前缀和发布名都以实际克隆的上游仓库为准。VIKINGYFY 源码标记为 `vikingyfy`；非 IPQ 设备即使在入口选择 `vikingyfy` 或 `libwrt`，构建结果也会标记为 `immortalwrt`。

三种入口共用同一套设备配置和构建脚本，通过 `SOURCE_TYPE`（`lean` / `vikingyfy` / `libwrt`）和 `WRT_FIREWALL` 参数区分。`vikingyfy` 与 `libwrt` 都属于 iwrt 配置族，默认使用 fw4；`lean` 默认使用 fw3。

## 支持设备

| 设备 | 架构 | 备注 |
|------|------|------|
| `CMIOT-AX18-NOWIFI` | qualcommax-ipq60xx / aarch64 | 默认无 Wi-Fi |
| `JD-AX1800PRO-WIFI` | qualcommax-ipq60xx / aarch64 | 京东云亚瑟，带 Wi-Fi |
| `JD-AX1800PRO-NOWIFI` | qualcommax-ipq60xx / aarch64 | 京东云亚瑟，无 Wi-Fi |
| `JD-AX6600-WIFI` | qualcommax-ipq60xx / aarch64 | 京东云雅典娜，带 Wi-Fi |
| `GL-MT6000-WIFI` | mediatek-filogic / aarch64 | GL.iNet MT6000，带 Wi-Fi |
| `GL-MT6000-NOWIFI` | mediatek-filogic / aarch64 | GL.iNet MT6000，无 Wi-Fi |

如需调整具体机型勾选项，修改对应配置文件中的 `CONFIG_TARGET_DEVICE_*`。

## CI 工作流

[![CUSTOM-LWRT](https://github.com/jw10126121/VWrt/actions/workflows/CUSTOM-LWRT.yml/badge.svg)](https://github.com/jw10126121/VWrt/actions/workflows/CUSTOM-LWRT.yml)
[![CUSTOM-IWRT](https://github.com/jw10126121/VWrt/actions/workflows/CUSTOM-iwrt.yml/badge.svg)](https://github.com/jw10126121/VWrt/actions/workflows/CUSTOM-iwrt.yml)
[![DEFAULT](https://github.com/jw10126121/VWrt/actions/workflows/DEFAULT.yml/badge.svg)](https://github.com/jw10126121/VWrt/actions/workflows/DEFAULT.yml)

### 预设工作流

| 工作流 | 触发方式 | 说明 |
|--------|----------|------|
| **CUSTOM-LWRT** | 手动 | 批量构建 fw3 风味的常用设备组合 |
| **CUSTOM-IWRT** | 手动 | 批量构建 fw4 风味的常用设备组合 |
| **CUSTOM-IWRT-ALL** | 手动 | 四任务批量构建，可选择 `vikingyfy` / `libwrt`；MT6000 均使用官方 ImmortalWrt |
| **DEFAULT** | 手动 | 单设备自定义构建，灵活选择参数 |
| **ForCache** | 手动 | 编译常用组合以预热工具链和 ccache 缓存 |

> 各工作流的 `schedule` 定时触发当前均已注释，需在 Actions 页面手动运行。

`CUSTOM-IWRT-ALL` 包含 AX18 无 Wi-Fi + frps、MT6000 有/无 Wi-Fi、AX6600 有 Wi-Fi，四个任务统一使用外部选择的 `SOURCE_TYPE`。该选项控制高通设备使用 VIKINGYFY 的 immortalwrt（入口和风味标记均为 `vikingyfy`）或 LibWrt `25.12-nss`（入口 `libwrt`）；MT6000 的两种配置始终使用官方 ImmortalWrt `master`，产物风味标记为 `immortalwrt`。包管理器由 `libwrt` 自动选择 APK，`vikingyfy` 沿用源码默认值。源码 HASH 留空时跟随各设备实际源码分支的最新提交；批量任务涉及不同仓库，填写 HASH 时须确保提交适用于全部设备。设备配置、插件脚本、LAN IP 和发布选项保持一致。

### DEFAULT 工作流参数

手动运行 `DEFAULT` 时，可输入以下参数：

| 参数 | 说明 | 示例 |
|------|------|------|
| `WRT_DEVICE` | 设备型号 | `CMIOT-AX18-NOWIFI` |
| `SOURCE_TYPE` | 构建入口 / 源码类型 | `lean` / `vikingyfy` / `libwrt` |
| `WRT_FIREWALL` | 防火墙栈 | `auto` / `fw3` / `fw4` |
| `WRT_FRP_MODE` | FRP 模式 | `frpc` / `frps` / `frp` / `none` |
| `WRT_USB_MODE` | USB 模式 | `default` / `usb` / `nousb` |
| `WRT_PACKAGE_MANAGER` | 包管理器 | `auto` / `apk` / `ipk` |
| `WRT_OVERLAYS` | 高级兜底差异层，逗号分隔 | `frps,nousb` |
| `WRT_EXTRA_CONFIGS` | 临时附加配置项 | `luci-app-mmw,CONFIG_PACKAGE_xxx=y` |
| `WRT_LUCI_BRANCH` | LuCI feed 分支 | `openwrt-23.05` |
| `WRT_DIYPackages` | 包脚本选择 | `auto`（默认）/ `Packages.sh` |
| `WRT_DEFAULT_LANIP` | 默认 LAN IP | `192.168.0.1` |
| `WRT_RELEASE_FIRMWARE` | 是否发布 Release | `true` / `false` |
| `WRT_SOURCE_HASH_INFO` | 固定 git 提交 | commit hash |

**参数说明：**

- `SOURCE_TYPE` 只决定构建入口；入口 `vikingyfy` 对应的 VIKINGYFY 源码风味标记为 `vikingyfy`，非 IPQ 设备会回退到官方 ImmortalWrt，风味按实际源码显示为 `immortalwrt`
- `WRT_LUCI_BRANCH` 留空时使用源码默认 LuCI feed
- `WRT_DIYPackages` 默认 `auto`：优先使用 `Scripts/Packages-<设备名>.sh` 或短名脚本；填 `Packages.sh` 可强制使用通用包脚本
- `WRT_FRP_MODE` 默认 `frpc`；`frp` 表示同时启用 `frpc` 与 `frps`，日常切换不再需要手输 overlay
- `WRT_USB_MODE` 默认 `default`，表示保持设备主配置中的 USB 能力；选 `usb/nousb` 时才额外叠加 overlay
- `WRT_PACKAGE_MANAGER` 默认 `auto`，表示沿用源码默认包管理器；选 `apk/ipk` 时会直接传给构建主流程
- `WRT_OVERLAYS` 保留为自定义 overlay 的高级兜底输入，会追加在结构化选项之后
- `WRT_EXTRA_CONFIGS` 用于临时追加 Kconfig 配置，支持 `luci-app-mmw`、`luci-app-mmw=y`、`CONFIG_PACKAGE_xxx=y` 等写法，可用空格、逗号或换行分隔
- overlay 文件可用 `# OVERLAY_GROUP=<组名>` 声明互斥组；同组内按 `WRT_OVERLAYS` 顺序以最后一个为准
- `WRT_SOURCE_HASH_INFO` 留空时使用所选源码分支的最新提交；填写时会在克隆后检出该提交。批量构建涉及不同源码仓库，固定 HASH 时需确保该提交适用于各设备。

**构建缓存：** 工具链缓存按 Runner 环境、源码仓库/分支、目标平台、最终 `.config` 中的非软件包配置和完整源码提交生成精确键；在配置和 Runner 镜像版本相同的范围内，可回退到较早源码提交的缓存。恢复后仍由 OpenWrt 检查依赖，不保证跳过工具链重建；工具链缓存仅在固件编译成功后保存。ccache 按 Runner 系统/架构、源码仓库/分支及目标平台隔离，精确键按设备配置标签区分，并可在同一范围内回退到其他配置的缓存；命中精确键后不重复保存。恢复缓存后会整理 staging 时间戳并打印命中状态与 ccache 统计。缓存不包含源码和 feeds；缓存键带版本前缀（当前工具链和 ccache 均为 `v4`），旧版本记录会自动隔离，首次构建工具链可能耗时较长。

## 配置组织

配置按以下顺序合并（后加载的内容覆盖前面的同名项）：

```
通用配置（按优先级取第一个匹配项）
  Config/general-<设备名>.txt      # 设备专用，如 general-cmiot-ax18-wifi.txt
  Config/general-<设备简写>.txt    # 去掉 -wifi/-nowifi 后的简写
  Config/general-<源码入口值>.txt  # 如 general-lean.txt、general-vikingyfy.txt
  Config/general-iwrt.txt          # iwrt 配置族（fw4 或 vikingyfy/libwrt）
  Config/general.txt               # 通用基线

设备主配置
  Config/<设备名>-fw4-iwrt.txt     # iwrt 配置族 / fw4 优先
  Config/<设备名>-fw3.txt          # fw3
  Config/<设备名>.txt              # 兼容旧文件名
  # nowifi 设备找不到自身配置时，回退到对应的 <短名>-wifi 配置

差异层
  Config/device-overlays/<设备名>-<FW>.txt  # 可选的设备差异层（当前仓库未使用）
  Config/overlays/<overlay>.txt             # 功能差异层，按 WRT_OVERLAYS 顺序叠加
```

通用配置只会选中一个文件，不会同时叠加设备专用配置和基线配置。所有合并完成后会按配置键去重，保留最后一次出现的值。

### 主维护配置文件

| 设备 | fw3 配置 | fw4 配置 |
|------|----------|----------|
| CMIOT-AX18 | `Config/cmiot-ax18-wifi-fw3.txt` | `Config/cmiot-ax18-wifi-fw4-iwrt.txt` |
| JD-AX1800PRO | `Config/jd-ax1800pro-wifi-fw3.txt` | `Config/jd-ax1800pro-wifi-fw4-iwrt.txt` |
| GL-MT6000-WIFI | `Config/gl-mt6000-wifi-fw3.txt` | `Config/gl-mt6000-wifi-fw4-iwrt.txt` |
| JD-AX6600-WIFI | `Config/jd-ax6600-wifi-fw3.txt` | `Config/jd-ax6600-wifi-fw4-iwrt.txt` |

`*-nowifi` 构建目标会自动复用对应 `*-wifi` 主配置，并追加 `nowifi-*` overlay。

## Overlay 系统

Overlay 用于在不修改设备主配置的前提下叠加功能差异。

### 内置 Overlay

| Overlay | 说明 |
|---------|------|
| `frpc` | FRP 内网穿透客户端 |
| `frps` | FRP 内网穿透服务端 |
| `frp` | 同时启用 FRP 客户端与服务端 |
| `usb` | USB 支持 |
| `nousb` | 移除 USB 支持 |
| `nowifi-ipq60xx` | IPQ60XX 设备移除 Wi-Fi |
| `nowifi-filogic` | Filogic（如 GL-MT6000）设备移除 Wi-Fi |

包管理器不是 overlay，请使用 `WRT_PACKAGE_MANAGER`（`auto` / `apk` / `ipk`）选择。`*-nowifi` 设备会根据平台自动追加对应的 `nowifi-*` overlay，无需手动填写。

### 自定义 Overlay

1. 在 `Config/overlays/` 下创建 `.txt` 文件，例如 `Config/overlays/myvpn.txt`
2. 使用时在 `WRT_OVERLAYS` 中填入文件名（不含扩展名），例如 `WRT_OVERLAYS=myvpn`
3. 后面的 overlay 会覆盖前面的同名配置
4. 可通过 `# OVERLAY_GROUP=<组名>` 声明互斥组，同组只保留最后出现的 overlay

## 固件默认值

| 项目 | 默认值 |
|------|--------|
| 主题 | Fluent（`WRT_THEME_NAME=auto`） |
| 主机名 | `Linjw` |
| LAN IP | `192.168.0.1` |
| 用户名 | `root` |
| 密码 | 空密码 |

## 下载固件

- **发布页**：[VWrt Releases](https://github.com/jw10126121/VWrt/releases)
- **上游源码**：[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)（Lean）| [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)（VIKINGYFY）| [LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt)（LibWrt）| [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)（官方 ImmortalWrt）

## 刷机说明

适用于当前 lean 固件：

| 刷机方式 | 固件文件 | 说明 |
|----------|----------|------|
| U-Boot 恢复 | `squashfs-recovery.bin` | 适用于 Hugo U-Boot + 原厂 CDT + 双分区 GPT |
| LuCI 在线升级 | `squashfs-sysupgrade.bin` | 在 LuCI 系统升级页面上传 |

---

> ⚠️ 本仓库仅供学习与交流使用，请自行评估刷机风险并遵守相关法律法规。

## 致谢

- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) — Lean大佬的 OpenWrt 源码
- [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) — VIKINGYFY大佬的 ImmortalWrt 源码
- [LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt) — LibWrt大佬的 OpenWrt 源码
- [OpenWrt](https://github.com/openwrt/openwrt) — OpenWrt 官方项目
- 感谢所有上游贡献者和社区用户的支持与反馈
- 本项目大部分功能由AI实现
