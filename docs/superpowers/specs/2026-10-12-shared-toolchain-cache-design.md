# 同 Target 软件包变体共享 Toolchain Cache 设计

**日期：** 2026-10-12

**状态：** 待实现

## 目标

让源码和工具链兼容条件相同、只在软件包选择上存在差异的构建共享一份 toolchain cache。

首个明确场景是：

- `gl-mt6000-wifi`
- `gl-mt6000-nowifi`

两者使用相同的源码、`mediatek/filogic` target/subtarget 和编译工具链；nowifi overlay 只移除无线驱动、固件、AP 组件及相关 LuCI 软件包，因此不应仅因这些软件包差异生成两份 toolchain cache。

## 当前行为

`Scripts/ci_cache_keys.py` 当前把完整 `.config` 的 SHA-256 纳入 `TOOLCHAIN_CACHE_KEY`。任何软件包选择变化都会改变 key，包括：

- `CONFIG_PACKAGE_*`
- `# CONFIG_PACKAGE_* is not set`
- `CONFIG_DEFAULT_*`
- `CONFIG_TARGET_DEVICE_PACKAGES_*`

因此 Wi-Fi 与 nowifi 配置会生成不同的精确 key，并分别保存约 500–600 MB 的 toolchain cache。

ccache 不存在相同的兼容性隔离问题：其兼容前缀已经按 runner、源码仓库、分支和 target/subtarget 计算，Wi-Fi 与 nowifi 可以通过 `restore-keys` 互相恢复。ccache 的滚动快照策略不属于本次修改范围。

## 方案选择

采用“规范化工具链配置指纹”，不使用设备名硬编码，也不为 toolchain 增加宽泛的 `restore-keys`。

选择该方案的原因：

1. 对所有“同兼容范围、仅软件包不同”的构建自动生效。
2. 不需要维护 `wifi`/`nowifi`、`frpc`/`frps` 等设备变体映射。
3. 仍然使用精确 key，避免回退到源码、架构或真实工具链选项不兼容的缓存。
4. 并行任务生成相同 key 时，现有 `continue-on-error: true` 可以容忍第二个任务保存时遇到缓存已被占用；最终只保留一份缓存。

## Key 设计

toolchain key 升级为：

```text
toolchain-v3-<compatibility_hash>
```

`compatibility_hash` 继续包含：

- `RUNNER_OS`
- `RUNNER_ARCH`
- `ImageOS`
- `ImageVersion`
- `WRT_REPO_URL`
- `WRT_REPO_BRANCH`
- `DEVICE_TARGET`
- `DEVICE_SUBTARGET`
- 完整 `REPO_GIT_HASH`
- `CACHE_SCRIPTS_HASH`
- 规范化后的工具链配置指纹

本次不放宽源码提交、runner 镜像或脚本兼容边界。

## 配置规范化

`Scripts/ci_cache_keys.py` 新增独立函数读取最终 `.config`，过滤纯软件包选择后再计算 SHA-256。

过滤以下已启用、赋值和未启用形式：

```text
CONFIG_PACKAGE_*
# CONFIG_PACKAGE_* is not set
CONFIG_DEFAULT_*
# CONFIG_DEFAULT_* is not set
CONFIG_TARGET_DEVICE_PACKAGES_*
# CONFIG_TARGET_DEVICE_PACKAGES_* is not set
```

其余非空行保留并排序，然后以换行连接后计算哈希。排序避免仅由配置行顺序造成无意义失效。

该策略是保守过滤：只忽略明确属于软件包选择的配置。以下变化仍然会改变 toolchain key：

- GCC、binutils、libc 或 LLVM 相关选项
- CPU、ABI、目标架构或编译优化选项
- 内核及其他非软件包构建选项
- target/subtarget
- 源码提交、仓库或分支
- runner 镜像
- `Scripts/**`

## Workflow 行为

`CORE-ALL.yml` 的 restore/save 结构和缓存路径保持不变：

```text
staging_dir/host*
staging_dir/tool*
```

不为 toolchain 设置 `restore-keys`。共享只发生在计算结果完全相同的精确 key 之间。

首次同时运行 Wi-Fi 与 nowifi 时：

1. 两个任务计算出相同的 toolchain key。
2. 如果该 key 尚不存在，两个任务都可能 miss 并各自完成构建。
3. 最先完成的任务保存缓存。
4. 另一个任务保存同 key 时可能遇到已存在的缓存，但现有 `continue-on-error` 会容忍该竞争。
5. 后续两种配置都恢复同一份缓存。

## 安全边界

共享缓存只作为构建加速输入，不替代 OpenWrt 自身的依赖检查。软件包及其目标产物不在 toolchain key 的兼容性定义中；缺失的包专用 host 工具仍由构建系统按需生成。

以下情况必须保持隔离：

- 不同 target/subtarget
- 不同源码仓库、分支或 commit
- 不同 runner OS、架构或镜像版本
- 不同非软件包 `.config` 选项
- 不同缓存生成脚本版本

## 测试要求

更新 `Scripts/tests/test_ci_cache_keys.py`：

1. key 前缀升级为 `toolchain-v3-`。
2. 单独改变 `CONFIG_PACKAGE_*` 不改变 toolchain key。
3. 已启用与 `is not set` 两种软件包写法都被忽略。
4. 改变 `CONFIG_DEFAULT_*` 不改变 toolchain key。
5. 改变 `CONFIG_TARGET_DEVICE_PACKAGES_*` 不改变 toolchain key。
6. 改变 GCC 等非软件包配置仍使 toolchain key 失效。
7. 源码 commit、脚本哈希、target/subtarget 和 runner 边界继续失效。
8. ccache key 行为保持不变。

继续运行 `Scripts/tests/test_workflow_cache_keys.sh`，确认：

- restore/save 仍使用完全相同的 toolchain key。
- toolchain 仍没有 `restore-keys`。
- ccache 滚动快照和前缀恢复行为未改变。

## 不在本次范围内

- 限制 ccache 大小
- 修改 ccache 的滚动快照 key
- 移除 `ImageVersion`
- 允许跨源码 commit 复用 toolchain
- 修改 toolchain 缓存目录
- 清理现有 `toolchain-v2-*` 缓存

旧的 v2 缓存由 GitHub Actions 按容量策略自然淘汰。

## 验收标准

1. 相同兼容范围内，仅软件包选择不同的两份 `.config` 生成相同 `TOOLCHAIN_CACHE_KEY`。
2. `gl-mt6000-wifi` 与 `gl-mt6000-nowifi` 在相同源码和 runner 条件下生成相同 toolchain key。
3. 任一非软件包工具链兼容输入变化时生成不同 key。
4. 所有缓存键单元测试和 workflow 缓存结构测试通过。
