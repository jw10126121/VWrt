# Cache Restore/Save Separation Design

**Date:** 2026-04-23

**Status:** Proposed

**Goal**

以当前 workflow 代码为前提，只解决现有缓存动作的结构问题：

- 把 `actions/cache` 单步 restore/save 改成显式分离
- 保持当前 cache key 语义不变
- 补最小必要的缓存观测日志

本次设计明确不预设 `dl` 缓存一定要做，只在文档中定义后续是否值得实现的判断标准。

## Current State

当前 [`CORE-ALL.yml`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CORE-ALL.yml:240) 已经有两处缓存：

1. `Check Toolchain Cache`
   - 使用 `actions/cache@v5`
   - key：
     `toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}`

2. `Check ccache Cache`
   - 使用 `actions/cache@v5`
   - key：
     `ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}`
   - restore-keys：
     `ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-`

当前问题不是 key 设计本身，而是缓存动作结构仍是单步 `actions/cache`。

在已有构建日志中，这个结构已经暴露出风险：

- 构建开始时 cache miss
- 构建结束时虽然目录里已有 `.ccache`
- 但保存阶段报：
  - `Failed to save: Unable to reserve cache with key ccache-Linux-ipq60xx-lede-master, another job may be creating this cache.`
  - `Failed to save: Unable to reserve cache with key toolchain-Linux-ipq60xx-lede-master-195fd0ec, another job may be creating this cache.`

这说明当前最先该解决的是“restore/save 行为可控”，而不是立即重做 key 粒度。

## Requirements

### Functional Requirements

1. `toolchain` 缓存改成 restore/save 分离
2. `ccache` 缓存改成 restore/save 分离
3. 当前 `toolchain` key 语义保持不变
4. `ccache` restore/save 需要支持滚动快照累积，而不是固定命中同一份不可变快照
5. workflow 增加最小必要的缓存与构建可观察性日志

### Non-Functional Requirements

1. 不在本次设计中调整 cache key 粒度
2. 不在本次设计中新增 `dl` 缓存实现
3. 不在本次设计中增加“手动废弃缓存”的新入口
4. 需要用脚本测试锁住新的 workflow 结构

## Design Decision

采用“**结构先行**”策略：

1. 先把现有 `toolchain` 和 `ccache` 从单步 `actions/cache` 改成 restore/save 分离
2. 保持 key、restore-keys、path 全部不变
3. 只增加最小日志，帮助后续判断缓存是否真正恢复和写回
4. `dl` 缓存只做后续评估，不在本轮实现

## Architecture

### 1. Toolchain Cache Structure

当前的 `Check Toolchain Cache` 将拆成两个 step：

#### Restore Toolchain Cache

- 使用 `actions/cache/restore@v5`
- 条件保持为：
  - `env.CACHE_TOOLCHAIN == 'true'`
- key 保持不变：
  - `toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}`
- path 保持不变：
  - `${{ env.OPENWRT_PATH }}/staging_dir/host*`
  - `${{ env.OPENWRT_PATH }}/staging_dir/tool*`

#### Save Toolchain Cache

- 使用 `actions/cache/save@v5`
- 条件保持以 `CACHE_TOOLCHAIN == true` 为前提，并增加目录存在性判断
- key 与 restore 使用完全相同的 key
- path 与 restore 使用完全相同的 path

本次设计不为 `toolchain` 新增 `restore-keys`，保持现有“强绑 commit hash”的行为不变。

### 2. ccache Cache Structure

当前的 `Check ccache Cache` 将拆成两个 step：

#### Restore ccache Cache

- 使用 `actions/cache/restore@v5`
- 条件保持为：
  - `env.CACHE_TOOLCHAIN == 'true'`
- key 保持不变：
  - `ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}`
- restore-keys 保持不变：
  - `ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-`
- path 保持不变：
  - `${{ env.OPENWRT_PATH }}/.ccache`

#### Save ccache Cache

- 使用 `actions/cache/save@v5`
- 条件保持以 `CACHE_TOOLCHAIN == true` 为前提，并增加目录存在性判断
- key 与当前 key 保持完全一致
- path 保持不变：
  - `${{ env.OPENWRT_PATH }}/.ccache`

`ccache` 在真实 CI 验证后补充调整为“滚动快照”策略：

- restore key 使用：
  - `ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.START_TIME }}`
- restore-keys 保持前缀回退：
  - `ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-`
- save key 使用：
  - `ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.START_TIME }}`

这样每轮构建都会从前缀命中的最近快照恢复，再把本轮更热的 `.ccache` 保存为一份新的不可变快照。

### 3. Refresh Cache Metadata

现有 [`Refresh Cache Metadata`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/.github/workflows/CORE-ALL.yml:261) 逻辑保留。

它仍然位于缓存 restore 之后、feeds 与编译步骤之前，用于：

- 更新时间戳
- 维持 toolchain 缓存恢复后的可用性
- 标记 `tmp/.build`

本次设计不重排其位置，也不改变其行为，只要求它继续运行在 restore 之后。

### 4. Minimal Observability

为了让后续判断 cache 是否“真的恢复了内容”和“save 前是否真的有内容”更直接，同时让缓存收益是否成立可从日志直接判断，本次设计只增加最小必要日志。

#### After Restore

增加一个轻量检查 step，输出：

1. `staging_dir` 是否存在
2. `.ccache` 是否存在
3. 如果 `.ccache` 存在，输出：
   - `du -sh "$OPENWRT_PATH/.ccache"`

#### Before Save

在 save 之前再输出一次：

1. `.ccache` 目录大小
2. `staging_dir/host*` 与 `staging_dir/tool*` 是否存在

#### ccache Stats

在编译前后各输出一次：

1. `ccache -s`

用于直接观察：

1. hits / misses
2. 当前 cache size

#### Stage Timing

输出以下阶段耗时：

1. restore 后到进入 `make download` 前的准备阶段
2. `make download`
3. `make -j...`

这些日志只用于观测，不改变 workflow 行为。

## dl Cache Evaluation Policy

本次设计明确不实现 `dl` 缓存，但保留后续评估入口。

是否值得在下一阶段加入 `dl` 缓存，只看两个问题：

1. `make download` 在连续构建中是否稳定占用可观时间
2. 在 restore/save 分离生效后，整体瓶颈是否仍明显落在下载阶段

如果后续日志显示：

- `make download` 只占几分钟
- 总体耗时仍主要集中在 `make` 编译本体

则 `dl` 缓存优先级仍应低于 `toolchain` 与 `ccache`。

## Out of Scope

以下内容不属于本次设计范围：

- 调整 `toolchain` key 粒度
- 调整 `ccache` key 粒度
- 新增 `CACHE_EPOCH`
- 新增“重置缓存”的手动开关
- 实现 `dl` 缓存
- 修改源码 checkout 策略
- 引入 release asset 作为缓存介质

## Testing Plan

本次只更新现有 workflow cache 测试，不新增 `dl` 相关测试。

需要更新的测试文件：

- [`Scripts/tests/test_workflow_cache_keys.sh`](/Users/lin/Documents/Git/Linjw/LjwOpenWrt/Scripts/tests/test_workflow_cache_keys.sh:1)

测试应覆盖：

1. `Restore Toolchain Cache` step 存在
2. `Save Toolchain Cache` step 存在
3. `toolchain` 仍使用当前 key：
   - `toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}`
4. `toolchain` 仍然没有 `restore-keys`
5. `Restore ccache Cache` step 存在
6. `Save ccache Cache` step 存在
7. `ccache` 仍使用当前 key：
   - `ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}`
8. `ccache` restore key 与 save key 使用 `START_TIME` 滚动快照
9. `ccache` 仍保留当前 `restore-keys` 前缀回退
10. workflow 输出编译前后的 `ccache -s`
11. workflow 输出 prep / download / compile 三段耗时
12. workflow 本轮不引入 `dl` cache step

## Rollout Plan

第一阶段：

1. 把当前两处 `actions/cache@v5` 改成 restore/save 分离
2. 保持 key、restore-keys、path 不变
3. 补上 restore 后与 save 前的最小日志

第二阶段：

1. 更新 workflow cache 测试
2. 运行现有 workflow 测试，确认结构已切换

第三阶段：

1. 在真实 CI 中观察至少两次连续构建
2. 验证：
   - restore step 的命中行为可从日志直接判断
   - save step 的执行行为可从日志直接判断
   - 是否仍存在 cache reserve 冲突

## Validation Notes

真实 CI 验证结论：

1. `toolchain` 缓存稳定有效，应继续保留
2. `ccache` 在固定 key 下会反复恢复同一份不可变快照，`before` 命中率停滞
3. 将 `ccache` 改成滚动 restore/save key 并保留前缀 `restore-keys` 后，`before` 命中率已从约 `10.63%` 提升到约 `23.02%`
4. `ccache` 的 `after` 命中率已达到约 `51.27%`，说明滚动快照正在继续变热
5. `make download` 仍然只占几分钟，当前主瓶颈仍然是 `compile`

## Risks

1. 即使改成 restore/save 分离，固定 key 仍可能在 save 阶段遇到竞争
2. `ccache` 滚动快照会增加 cache 条目数量，后续可能需要单独的清理策略
3. 只加最小日志意味着本次不会直接解决所有 cache 调优问题

## Recommendation

按以下顺序实施：

1. 先做 restore/save 分离，解决当前结构性问题
2. 保持 `toolchain` 精确 key，不要和 `ccache` 一起改
3. 对 `ccache` 使用滚动 restore/save key 和前缀回退，允许快照持续变热
4. 用 benchmark summary 持续观察 `before/after` 命中率与 `compile(s)` 走势
5. 只在 `download` 明显重新成为主瓶颈时，再考虑 `dl` 缓存
