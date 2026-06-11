# Lang Node Prebuilt Dual-Format Design

**Date:** 2026-04-20

**Status:** Proposed

**Goal**

让当前仓库在源码编译阶段继续通过预编译 Node 内容规避官方 `lang/node` 本地源码编译，但把现有仅支持 `24.10/ipk` 的接入方式扩展为同一入口自动支持：

- `OpenWrt 24.10 + ipk`
- `OpenWrt 25.12 + apk`

并允许预编译内容来自官方 OpenWrt release 仓库或自定义镜像/第三方仓库。

## Current State

当前仓库已经有一条 `lang_node` 预编译接入链：

- [`Scripts/Packages.sh`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/Packages.sh:376) 在后置修补链中调用 `apply_lang_node_prebuilt_fix`
- [`Scripts/lib/lang_node_prebuilt.sh`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/lib/lang_node_prebuilt.sh:1) 负责识别 OpenWrt 版本、查询预编译分支、替换 `feeds/packages/lang/node`
- 现有策略会在 `apk` 模式直接跳过 `sbwml/feeds_packages_lang_node-prebuilt`
- 现有测试只覆盖 `24.10/ipk` 及“`25.12` 回退到 `24.10` 分支”的兼容逻辑

这个实现的核心问题不是结构，而是策略已经过时：

- 只按 `OpenWrt x.y` 版本选分支，不看包格式
- 允许 `25.12 -> 24.10` 的跨格式回退
- 默认假设预编译内容来自 `.ipk` 仓库

对 `25.12` 来说，上述前提都不再成立，因为 `25.12` 已切到 `apk`。

## Requirements

### Functional Requirements

1. 同一入口自动识别当前源码树是 `ipk` 还是 `apk`
2. `24.10/ipk` 继续使用预编译 Node 替换官方 `lang/node`
3. `25.12/apk` 新增预编译 Node 替换官方 `lang/node`
4. 允许使用官方 OpenWrt release 仓库或第三方镜像作为预编译来源
5. 替换失败时必须回滚原始 `feeds/packages/lang/node`

### Non-Functional Requirements

1. 不改变现有 `Packages.sh` 调用入口
2. 不把问题扩展成运行时第三方 feed 管理
3. 第一版只覆盖 `node` 与 `node-npm`
4. 不能因为自动识别失败而破坏原始 feeds 目录

## Design Decision

采用“**同一入口，按版本和包格式选择不同后端策略**”。

具体来说：

- 保留一个统一 helper：`Scripts/lib/lang_node_prebuilt.sh`
- helper 先识别当前 OpenWrt 主次版本和包格式
- helper 再在同一个预编译仓库中选择匹配的后端分支
- `24.10/ipk` 和 `25.12/apk` 分别使用不同分支和不同下载/解包逻辑
- 明确禁止 `apk` 与 `ipk` 之间跨格式回退

这是第一版最稳的方案，因为它只扩大了已有预编译替换机制的能力边界，没有把问题扩大成新的包管理分发系统。

## Architecture

### 1. Entry Point

[`Scripts/Packages.sh`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/Packages.sh:376) 继续保留 `apply_lang_node_prebuilt_fix` 作为唯一入口，但去掉“`APK 模式直接跳过`”逻辑。

入口职责收敛为：

1. 输出统一日志
2. 调用 `Scripts/lib/lang_node_prebuilt.sh`
3. 成功则继续后续修补
4. 失败则记录日志并继续使用官方 `lang/node`

### 2. Strategy Selection

[`Scripts/lib/lang_node_prebuilt.sh`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/lib/lang_node_prebuilt.sh:1) 从“按版本挑分支”升级为“按格式挑策略，再按版本挑分支”。

检测顺序：

1. 从 `.config` 读取 `CONFIG_PKG_FORMAT`
2. 若无值，则从 `CONFIG_VERSION_NUMBER`、`include/version.mk`、`feeds.conf.default` 推导 OpenWrt 主次版本
3. 若包格式仍无法确定，则按版本推断：
   - `25.12` 及更新版本视为 `apk`
   - `24.10` 及更早版本视为 `ipk`

选择结果不再只是单个 `selected_version`，而是逻辑上同时得到：

- `selected_pkg_format`
- `selected_branch`
- `selected_strategy`

示例：

- `24.10 + ipk` -> `packages-24.10` + `legacy_ipk`
- `25.12 + apk` -> `packages-25.12` + `apk_repack`

### 3. Compatibility Rules

兼容性规则定义如下：

1. `ipk` 只能命中 `ipk` 线分支
2. `apk` 只能命中 `apk` 线分支
3. 禁止 `25.12/apk -> 24.10/ipk` 跨格式回退
4. 禁止 `24.10/ipk -> 25.12/apk` 跨格式回退
5. 仅允许“同格式内”的兼容回退

第一版实际支持矩阵固定为：

- `packages-24.10` 对应 `ipk`
- `packages-25.12` 对应 `apk`

因此第一版的兼容回退空间非常小，重点是禁止错误命中。

### 4. Replace and Rollback

保留当前 helper 中已经验证过的替换流程：

1. 备份原始 `feeds/packages/lang/node`
2. 拉取选中的预编译分支
3. 修正分支内部版本变量
4. 成功则删除备份
5. 任一步失败则回滚

这部分不做架构变更，只扩展选择策略和日志内容。

## Prebuilt Feed Repository Design

预编译仓库继续只服务于 `feeds/packages/lang/node` 替换，不承担运行时软件源职责。

### Branch Layout

仓库中至少维护以下稳定分支：

- `packages-24.10`
- `packages-25.12`

不采用“单分支同时兼容两种包格式”的设计，因为真正需要自动识别的是本仓库 helper，而不是预编译 feed 分支本身。

### packages-24.10

保留当前 `sbwml` 风格实现：

- 下载宿主机预编译 Node 到 `STAGING_DIR_HOST`
- 从 `24.10` release 仓库抓取 `node` 与 `node-npm` 的 `.ipk`
- 解包 `.ipk`，提取目标内容，再按 OpenWrt 包规则安装

### packages-25.12

新增一个独立的 `apk` 后端实现，职责与 `24.10` 分支一致，但数据源和解包方式改为 `apk`：

- 下载宿主机预编译 Node 到 `STAGING_DIR_HOST`
- 从 `25.12` release 仓库或自定义镜像抓取 `node` 与 `node-npm` 的 `.apk`
- 解包 `.apk`，提取目标内容，再按 OpenWrt 包规则安装

`packages-25.12` 不复用 `packages-24.10` 中“读取 `Packages` 文本索引并解 `.ipk`”的实现。

## Source Configuration

为同时支持官方源与自定义镜像，设计两层可配置变量。

### Helper Layer Variables

- `LANG_NODE_PREBUILT_REPO`
  - 预编译 feed 仓库地址
- `LANG_NODE_FORCE_PKG_FORMAT`
  - 测试或特殊场景下强制指定 `ipk` / `apk`
- `LANG_NODE_ALLOW_SAME_FORMAT_FALLBACK`
  - 是否允许同格式内版本回退

### Feed Makefile Variables

`packages-25.12` 分支中的 `Makefile` 需要支持：

- `NODE_PREBUILT_MIRROR`
- `NODE_PREBUILT_RELEASE_BASE`
- `NODE_PREBUILT_PACKAGES_ARCH`

默认值指向官方 OpenWrt `25.12` release 仓库；如果有第三方镜像，只覆盖 URL，不改逻辑。

## Testing Plan

至少覆盖以下场景：

1. `24.10 + ipk + packages-24.10 存在`：成功替换
2. `25.12 + apk + packages-25.12 存在`：成功替换
3. `25.12 + apk + 只有 packages-24.10`：替换失败并回滚
4. `24.10 + ipk + 只有 packages-25.12`：替换失败并回滚
5. `VIKINGYFY/SNAPSHOT + ipk 线索`：命中 `24.10/ipk`
6. `VIKINGYFY/SNAPSHOT + apk 线索`：命中 `25.12/apk`

需要更新的测试文件：

- [`Scripts/test_lang_node_prebuilt.sh`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/test_lang_node_prebuilt.sh:1)
- [`Scripts/test_nxhack_node_test_target.sh`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/test_nxhack_node_test_target.sh:1)

## Rollout Plan

第一阶段：

- 只改 helper 和测试
- 让主仓库能正确区分 `ipk/apk`
- 去掉 `apk` 模式强制跳过逻辑

第二阶段：

- 准备 `packages-25.12` 分支
- 完成 `.apk` 下载与解包实现
- 接入镜像配置变量

第三阶段：

- 在实际 `24.10/ipk` 与 `25.12/apk` 源码树中各跑一次验证
- 确认失败时能稳定回退到官方 `lang/node`

## Out of Scope

以下内容不属于本次设计范围：

- 运行时 `/etc/apk/repositories.d/*.list` 管理
- 通用第三方 feed 分发平台
- 所有依赖 Node 的包定义统一改造
- 除 `node` 与 `node-npm` 之外的更多预编译 Node 生态包

## Risks

1. `25.12` 的 `.apk` 内部布局与假设不一致，导致需要额外调整解包步骤
2. 第三方镜像的文件命名或索引方式与官方仓库不完全一致
3. `SNAPSHOT` 树的格式与版本线索可能不一致，需依赖更严格的优先级判断

## Recommendation

按以下顺序进入实现：

1. 先改 helper 选择逻辑，消除错误的跨格式回退
2. 再补 `packages-25.12` 分支，实现 `apk` 后端
3. 最后扩充测试矩阵并在真实源码树验证

这个顺序能保证就算 `apk` 后端还没完成，也不会再错误地把 `25.12` 命中到 `24.10/ipk` 分支。
